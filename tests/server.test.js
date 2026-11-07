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
  for (const endpoint of ['/', '/phone', '/obs', '/view', '/app.css', '/phone.js']) {
    const r = await fetch(base + endpoint);
    assert.equal(r.status, 200, endpoint);
  }
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
