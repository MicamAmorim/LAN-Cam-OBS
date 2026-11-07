'use strict';

const http = require('node:http');
const https = require('node:https');
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { WebSocket, WebSocketServer } = require('./lib/ws-lite');

const HTTP_PORT = Number(process.env.HTTP_PORT || 8787);
const HTTPS_PORT = Number(process.env.HTTPS_PORT || 8788);
const HOST = process.env.HOST || '0.0.0.0';
const ROOT = __dirname;
const STATE_FILE = path.join(ROOT, '.local', 'state.json');
const CERT = path.join(ROOT, 'certs', 'lan.pem');
const KEY = path.join(ROOT, 'certs', 'lan-key.pem');
const ROOT_CA = path.join(ROOT, 'certs', 'rootCA.crt');
const STATIC = Object.freeze({
  '/': ['index.html', 'text/html; charset=utf-8'],
  '/phone': ['phone.html', 'text/html; charset=utf-8'],
  '/obs': ['viewer.html', 'text/html; charset=utf-8'],
  '/view': ['viewer.html', 'text/html; charset=utf-8'],
  '/app.css': ['app.css', 'text/css; charset=utf-8'],
  '/dashboard.js': ['dashboard.js', 'text/javascript; charset=utf-8'],
  '/vendor/qrcode.js': ['vendor/qrcode.js', 'text/javascript; charset=utf-8'],
  '/phone.js': ['phone.js', 'text/javascript; charset=utf-8'],
  '/viewer.js': ['viewer.js', 'text/javascript; charset=utf-8'],
  '/favicon.svg': ['favicon.svg', 'image/svg+xml']
});

function getKey() {
  if (process.env.ACCESS_KEY) {
    if (!/^[a-zA-Z0-9_-]{16,128}$/.test(process.env.ACCESS_KEY)) {
      throw new Error('ACCESS_KEY deve ter de 16 a 128 caracteres (A-Z, 0-9, _ ou -).');
    }
    return process.env.ACCESS_KEY;
  }
  try {
    const saved = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    if (/^[a-zA-Z0-9_-]{16,128}$/.test(saved.key)) return saved.key;
  } catch (_) {}
  const key = crypto.randomBytes(24).toString('base64url');
  fs.mkdirSync(path.dirname(STATE_FILE), { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify({ key }, null, 2), { mode: 0o600, flag: 'wx' });
  return key;
}
const accessKey = getKey();
const viewers = new Map();
let publisher = null;
let publishedMode = 'webrtc';
const peers = new Set();

const isLoopback = address => ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(address);
const networkIps = () => Object.values(os.networkInterfaces())
  .flat().filter(Boolean)
  .filter(item => item.family === 'IPv4' && !item.internal)
  .map(item => item.address);
const sendJson = (ws, obj) => {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
};
const broadcast = obj => { for (const client of viewers.values()) sendJson(client, obj); };
const notifyPublisher = obj => sendJson(publisher, obj);

function response(req, res) {
  let pathname;
  try { pathname = new URL(req.url, 'http://local.invalid').pathname; }
  catch { res.writeHead(400).end(); return; }
  if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405).end(); return; }
  const headers = {
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'no-referrer',
    'Cache-Control': 'no-store',
    'Permissions-Policy': 'camera=(self), microphone=(self)',
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; media-src blob:; connect-src 'self' ws: wss:; object-src 'none'; base-uri 'none'"
  };
  if (pathname === '/api/config' || pathname === '/api/status') {
    if (!isLoopback(req.socket.remoteAddress)) { res.writeHead(403, headers).end('Painel disponível apenas no computador.'); return; }
    const ips = networkIps();
    const payload = pathname === '/api/config'
      ? { key: accessKey, httpPort: HTTP_PORT, httpsPort: HTTPS_PORT, httpsReady: fs.existsSync(CERT) && fs.existsSync(KEY), ips }
      : { connected: Boolean(publisher), mode: publishedMode, viewers: viewers.size };
    res.writeHead(200, { ...headers, 'Content-Type': 'application/json; charset=utf-8' });
    res.end(JSON.stringify(payload)); return;
  }
  let file, type;
  if (pathname === '/local-ca.crt' && fs.existsSync(ROOT_CA)) {
    file = ROOT_CA; type = 'application/x-x509-ca-cert';
  } else if (Object.hasOwn(STATIC, pathname)) {
    [file, type] = STATIC[pathname]; file = path.join(ROOT, 'public', file);
  } else { res.writeHead(404, headers).end('Não encontrado'); return; }
  const stream = fs.createReadStream(file);
  stream.once('error', () => { if (!res.headersSent) res.writeHead(500, headers); res.end('Erro ao ler arquivo'); });
  res.writeHead(200, { ...headers, 'Content-Type': type });
  if (req.method === 'HEAD') { stream.destroy(); res.end(); return; }
  stream.pipe(res);
}

const wss = new WebSocketServer({ noServer: true, maxPayload: 1_600_000, perMessageDeflate: false });
function upgrade(req, socket, head) {
  let url;
  try { url = new URL(req.url, 'http://local.invalid'); }
  catch { socket.destroy(); return; }
  const role = url.searchParams.get('role');
  const key = url.searchParams.get('key');
  if (url.pathname !== '/signal' || !['phone', 'viewer'].includes(role) || key !== accessKey) {
    socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); socket.destroy(); return;
  }
  // Restringe scripts de outras origens que tentem usar a porta local.
  if (req.headers.origin) {
    try {
      const origin = new URL(req.headers.origin);
      if (origin.host !== req.headers.host || !['http:', 'https:'].includes(origin.protocol)) throw Error('origin');
    } catch { socket.write('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); socket.destroy(); return; }
  }
  wss.handleUpgrade(req, socket, head, ws => {
    ws.role = role;
    wss.emit('connection', ws);
  });
}

wss.on('connection', ws => {
  ws.id = crypto.randomBytes(8).toString('hex');
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  peers.add(ws);
  if (ws.role === 'phone') {
    if (publisher && publisher !== ws) publisher.close(4001, 'Outra câmera assumiu a transmissão');
    publisher = ws;
    publishedMode = 'webrtc';
    sendJson(ws, { type: 'welcome', id: ws.id, viewers: [...viewers.keys()] });
    broadcast({ type: 'publisher-online', mode: publishedMode });
  } else {
    viewers.set(ws.id, ws);
    sendJson(ws, { type: 'welcome', id: ws.id, publisherOnline: !!publisher, mode: publishedMode });
    notifyPublisher({ type: 'viewer-joined', id: ws.id });
  }
  ws.on('message', (raw, isBinary) => {
    if (isBinary) {
      if (ws === publisher && publishedMode === 'jpeg') {
        for (const v of viewers.values()) {
          if (v.readyState === WebSocket.OPEN && v.bufferedAmount < 1_500_000) v.send(raw, { binary: true });
        }
      }
      return;
    }
    if (raw.length > 250_000) return;
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }
    if (!msg || typeof msg.type !== 'string') return;
    if (ws === publisher) {
      if (msg.type === 'mode' && ['webrtc', 'jpeg'].includes(msg.mode)) {
        publishedMode = msg.mode;
        broadcast({ type: 'mode', mode: publishedMode });
        return;
      }
      if (['offer', 'ice'].includes(msg.type) && typeof msg.to === 'string' && viewers.has(msg.to)) {
        sendJson(viewers.get(msg.to), { type: msg.type, from: ws.id, sdp: msg.sdp, candidate: msg.candidate });
      }
    } else if (viewers.get(ws.id) === ws) {
      if (['answer', 'ice', 'viewer-reset'].includes(msg.type)) {
        notifyPublisher({ type: msg.type, from: ws.id, sdp: msg.sdp, candidate: msg.candidate });
      }
    }
  });
  ws.on('close', () => {
    peers.delete(ws);
    if (publisher === ws) { publisher = null; broadcast({ type: 'publisher-offline' }); }
    if (viewers.get(ws.id) === ws) { viewers.delete(ws.id); notifyPublisher({ type: 'viewer-left', id: ws.id }); }
  });
  ws.on('error', () => {});
});
setInterval(() => {
  for (const peer of peers) {
    if (!peer.isAlive) { peer.terminate(); continue; }
    peer.isAlive = false;
    peer.ping();
  }
}, 30_000).unref();

function start() {
  const httpServer = http.createServer(response);
  httpServer.on('upgrade', upgrade);
  httpServer.listen(HTTP_PORT, HOST, () => {
    console.log(`\nLAN Cam OBS - painel/OBS: http://localhost:${HTTP_PORT}`);
    console.log(`Rede local (para baixar certificado): ${networkIps().map(ip => `http://${ip}:${HTTP_PORT}`).join(', ') || '(sem IPv4 encontrada)'}`);
  });
  if (fs.existsSync(CERT) && fs.existsSync(KEY)) {
    const httpsServer = https.createServer({ cert: fs.readFileSync(CERT), key: fs.readFileSync(KEY) }, response);
    httpsServer.on('upgrade', upgrade);
    httpsServer.listen(HTTPS_PORT, HOST, () => console.log(`HTTPS celular: ${networkIps().map(ip => `https://${ip}:${HTTPS_PORT}/phone`).join(', ')}`));
  } else {
    console.log('HTTPS ainda não configurado. Use scripts/setup-https.ps1 para acesso pelo Wi-Fi.');
    console.log('USB/ADB pode funcionar sem HTTPS ao abrir http://localhost no próprio celular.');
  }
}

if (require.main === module) start();
module.exports = { response, upgrade, getKey, isLoopback, start };
