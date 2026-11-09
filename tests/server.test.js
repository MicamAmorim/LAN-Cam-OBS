'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const crypto = require('node:crypto');
const fs = require('node:fs');
const basePort = 20000 + crypto.randomInt(10000);
const key = 'local_test_access_key_12345';
const base = `http://127.0.0.1:${basePort}`;
let server;
let wsConnections = [];
function delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
async function waitUntilReady() {
  for (let i = 0; i < 80; ++i) {
    if (server.exitCode !== null) throw Error('Processo encerrou antes de iniciar.');
    try { if ((await fetch(base)).ok) return; } catch (_) {}
    await delay(60);
  }
  throw Error('Servidor não iniciou dentro do prazo.');
}
function openWs(role) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(`ws://127.0.0.1:${basePort}/signal?role=${role}&key=${key}`);
    ws.binaryType = 'arraybuffer';
    const messages = [];
    ws.addEventListener('message', event => {
      try { messages.push(typeof event.data === 'string' ? JSON.parse(event.data) : event.data); }
      catch (_) {}
    });
    ws.addEventListener('open', () => { wsConnections.push(ws); resolve({ ws, messages }); }, { once: true });
    ws.addEventListener('error', err => reject(err), { once: true });
  });
}
async function received(messages, predicate) {
  for (let i = 0; i < 120; i++) {
    const found = messages.find(predicate);
    if (found !== undefined) return found;
    await delay(20);
  }
  throw Error(`Mensagem esperada ausente; recebi: ${JSON.stringify(messages)}`);
}

test.before(async () => {
  server = spawn(process.execPath, ['server.js'], {
    cwd: path.resolve(__dirname, '..'),
    env: { ...process.env, HTTP_PORT: String(basePort), HTTPS_PORT: String(basePort + 1), ACCESS_KEY: key, HOST: '127.0.0.1' },
    stdio: 'ignore'
  });
  await waitUntilReady();
});
test.after(async () => {
  for (const ws of wsConnections) ws.close();
  server.kill('SIGTERM');
});

test('páginas, tipos e painel são servidos corretamente', async () => {
  for (const endpoint of ['/', '/phone', '/obs', '/view', '/app.css', '/phone.js', '/dashboard.js', '/vendor/qrcode.js']) {
    const r = await fetch(base + endpoint);
    assert.equal(r.status, 200, endpoint);
  }
  const dashboard = await (await fetch(base + '/')).text();
  assert.match(dashboard, /id="phoneQr"/, 'O painel deve incluir QR Code para o celular');
  assert.match(dashboard, /src="\/vendor\/qrcode\.js"/, 'O QR deve usar biblioteca local');
  const qrLib = await fetch(base + '/vendor/qrcode.js');
  assert.match(qrLib.headers.get('content-type'), /javascript/);
  const r = await fetch(base + '/api/config');
  const cfg = await r.json();
  assert.equal(cfg.key, key);
  assert.equal(cfg.httpPort, basePort);
  const certDir = path.resolve(__dirname, '..', 'certs');
  const hasLocalCertificate = fs.existsSync(path.join(certDir, 'lan.pem'))
    && fs.existsSync(path.join(certDir, 'lan-key.pem'));
  assert.equal(cfg.httpsReady, hasLocalCertificate, 'O status HTTPS deve refletir os certificados instalados');
  assert.equal((await fetch(base + '/missing')).status, 404);
});

test('sinalização, permissão de papel e entrega de quadros JPEG', { skip: typeof WebSocket === 'undefined' }, async () => {
  const viewer = await openWs('viewer');
  const vw = await received(viewer.messages, m => m.type === 'welcome');
  assert.equal(vw.publisherOnline, false);
  const phone = await openWs('phone');
  const pw = await received(phone.messages, m => m.type === 'welcome');
  assert.equal(pw.viewers.length, 1);
  await received(viewer.messages, m => m.type === 'publisher-online');
  assert.equal(pw.viewers[0], vw.id);
  viewer.ws.send(JSON.stringify({ type: 'mode', mode: 'jpeg' }));
  let s = await (await fetch(base + '/api/status')).json();
  assert.equal(s.mode, 'webrtc'); // visualizador não pode alterar transporte
  phone.ws.send(JSON.stringify({ type: 'offer', to: vw.id, sdp: { type: 'offer', sdp: 'test' } }));
  const offer = await received(viewer.messages, m => m.type === 'offer');
  assert.equal(offer.sdp.sdp, 'test');
  viewer.ws.send(JSON.stringify({ type: 'answer', sdp: { type: 'answer', sdp: 'response' } }));
  const answer = await received(phone.messages, m => m.type === 'answer');
  assert.equal(answer.sdp.sdp, 'response');
  phone.ws.send(JSON.stringify({ type: 'mode', mode: 'jpeg' }));
  await received(viewer.messages, m => m.type === 'mode' && m.mode === 'jpeg');
  const sample = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  phone.ws.send(sample);
  const jpeg = await received(viewer.messages, m => m instanceof ArrayBuffer);
  assert.deepEqual(new Uint8Array(jpeg), sample);
  s = await (await fetch(base + '/api/status')).json();
  assert.equal(s.connected, true);
  assert.equal(s.viewers, 1);
  phone.ws.close();
  await received(viewer.messages, m => m.type === 'publisher-offline');
  viewer.ws.close();
});


test('gerador QR local codifica o link HTTPS com chave de acesso', () => {
  const qrcode = require('../public/vendor/qrcode.js');
  const url = `https://192.168.1.11:8788/phone?key=${key}`;
  const qr = qrcode(0, 'M');
  qr.addData(url);
  qr.make();
  const count = qr.getModuleCount();
  assert.ok(count >= 21 && count <= 177, 'matriz QR dentro do padrao');
  assert.equal(qr.isDark(0, 0), true, 'marcador de posicao presente');
  assert.equal(qr.isDark(0, 6), true, 'marcador de posicao presente');
});

test('controle da webcam exige acesso local e cabecalho de protecao', async () => {
  const info = await (await fetch(base + '/api/status')).json();
  assert.equal(typeof info.webcam.supported, 'boolean');
  assert.equal(info.webcam.deviceName, 'LAN Cam Webcam');
  const notPost = await fetch(base + '/api/webcam/start');
  assert.equal(notPost.status, 405);
  const csrf = await fetch(base + '/api/webcam/start', { method: 'POST' });
  assert.equal(csrf.status, 403, 'sites externos nao podem ativar a webcam por requisicao simples');
  const fakeOrigin = await fetch(base + '/api/webcam/start', {
    method: 'POST',
    headers: { 'X-LAN-CAM': 'dashboard', Origin: 'https://example.net' }
  });
  assert.equal(fakeOrigin.status, 403);
  const dashboard = await (await fetch(base + '/')).text();
  assert.match(dashboard, /id="webcamStart"/);
  assert.match(dashboard, /id="selectWebcam"/);
});

test('painel unificado controla transmissões e protege ações de configuração', async () => {
  const setup = await (await fetch(base + '/api/setup')).json();
  assert.equal(typeof setup.driver.x64, 'boolean');
  assert.equal(typeof setup.job.running, 'boolean');
  for (const endpoint of ['/api/system/stop', '/api/setup/all', '/api/setup/wifi', '/api/setup/driver', '/api/setup/remove']) {
    assert.equal((await fetch(base + endpoint, { method: 'POST' })).status, 403);
    assert.equal((await fetch(base + endpoint, { method: 'POST', headers: { 'X-LAN-CAM': 'dashboard', Origin: 'https://example.org' } })).status, 403);
  }
  const phone = await openWs('phone');
  const closed = new Promise(resolve => phone.ws.addEventListener('close', resolve, { once: true }));
  const options = { method: 'POST', headers: { 'X-LAN-CAM': 'dashboard' } };
  assert.equal((await fetch(base + '/api/system/stop', options)).status, 200);
  await closed;
  assert.equal((await (await fetch(base + '/api/status')).json()).systemEnabled, false);
  assert.equal((await fetch(base + '/')).status, 200, 'painel continua disponível para religar');
  await assert.rejects(openWs('phone'), 'sistema desligado rejeita transmissões');
  assert.equal((await fetch(base + '/api/webcam/start', options)).status, 501);
  assert.equal((await fetch(base + '/api/system/start', options)).status, 200);
  const reconnected = await openWs('phone');
  reconnected.ws.close();
});
