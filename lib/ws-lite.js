'use strict';
// WebSocket RFC 6455 minimalista para navegadores; sem dependências npm.
// Implementa upgrade, máscara de cliente, fragmentação, ping/pong e limite de tamanho.
const crypto = require('node:crypto');
const { EventEmitter } = require('node:events');
const GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

class WebSocket extends EventEmitter {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;
  constructor(socket, maxPayload) {
    super();
    this.socket = socket;
    this.maxPayload = maxPayload;
    this.readyState = WebSocket.OPEN;
    this._buffer = Buffer.alloc(0);
    this._fragmentOpcode = 0;
    this._fragmentParts = [];
    this._fragmentBytes = 0;
    this._closed = false;
    socket.on('data', data => this._parse(data));
    socket.on('close', () => this._handleClose());
    socket.on('end', () => this._handleClose());
    socket.on('error', err => { this.emit('error', err); this._handleClose(); });
  }
  get bufferedAmount() { return this.socket.writableLength; }
  _handleClose() {
    if (this._closed) return;
    this._closed = true;
    this.readyState = WebSocket.CLOSED;
    this.emit('close');
  }
  _frame(opcode, body = Buffer.alloc(0)) {
    if (this.readyState !== WebSocket.OPEN) return;
    if (!Buffer.isBuffer(body)) body = Buffer.from(body);
    const n = body.length;
    const headerLen = n <= 125 ? 2 : n <= 65535 ? 4 : 10;
    const h = Buffer.alloc(headerLen);
    h[0] = 0x80 | opcode;
    if (headerLen === 2) h[1] = n;
    else if (headerLen === 4) { h[1] = 126; h.writeUInt16BE(n, 2); }
    else { h[1] = 127; h.writeBigUInt64BE(BigInt(n), 2); }
    this.socket.write(Buffer.concat([h, body]));
  }
  send(value, opts = {}) { this._frame(opts.binary || Buffer.isBuffer(value) ? 0x2 : 0x1, value); }
  ping() { this._frame(0x9); }
  terminate() { this.socket.destroy(); }
  close(code = 1000, reason = '') {
    if (this.readyState !== WebSocket.OPEN) return;
    const message = Buffer.from(reason).subarray(0, 123);
    const b = Buffer.alloc(2 + message.length);
    b.writeUInt16BE(code, 0); message.copy(b, 2);
    this._frame(0x8, b);
    this.readyState = WebSocket.CLOSING;
    this.socket.end();
    setTimeout(() => { if (!this.socket.destroyed) this.socket.destroy(); }, 1000).unref();
  }
  _badFrame() { this.close(1002, 'Invalid frame'); this.socket.destroy(); }
  _parse(data) {
    this._buffer = Buffer.concat([this._buffer, data]);
    if (this._buffer.length > this.maxPayload + 100) { this.close(1009, 'Too large'); return; }
    while (this._buffer.length >= 2 && this.readyState === WebSocket.OPEN) {
      const b0 = this._buffer[0], b1 = this._buffer[1];
      const fin = Boolean(b0 & 0x80), opcode = b0 & 0x0f;
      if ((b0 & 0x70) !== 0) return this._badFrame();
      if (!(b1 & 0x80)) return this._badFrame(); // browsers MUST mask data to servers
      const code = b1 & 0x7f;
      const offset = code === 126 ? 4 : code === 127 ? 10 : 2;
      if (this._buffer.length < offset + 4) return;
      const len = code === 126 ? this._buffer.readUInt16BE(2)
        : code === 127 ? this._buffer.readBigUInt64BE(2) : BigInt(code);
      const numeric = typeof len === 'bigint' ? len : BigInt(len);
      if (numeric > BigInt(this.maxPayload) || numeric > BigInt(Number.MAX_SAFE_INTEGER)) {
        this.close(1009, 'Too large'); return;
      }
      const size = Number(numeric);
      if (opcode >= 8 && (!fin || size > 125)) return this._badFrame();
      if (this._buffer.length < offset + 4 + size) return;
      const mask = this._buffer.subarray(offset, offset + 4);
      const payload = Buffer.from(this._buffer.subarray(offset + 4, offset + 4 + size));
      this._buffer = this._buffer.subarray(offset + 4 + size);
      for (let i = 0; i < size; ++i) payload[i] ^= mask[i & 3];
      if (opcode === 0x8) { this._frame(0x8, payload); this.socket.end(); this.readyState = WebSocket.CLOSING; return; }
      if (opcode === 0x9) { this._frame(0xA, payload); continue; }
      if (opcode === 0xA) { this.emit('pong'); continue; }
      if (![0, 1, 2].includes(opcode)) return this._badFrame();
      if (opcode === 0 && !this._fragmentOpcode) return this._badFrame();
      if (opcode !== 0 && this._fragmentOpcode) return this._badFrame();
      if (opcode !== 0 && !fin) this._fragmentOpcode = opcode;
      this._fragmentParts.push(payload);
      this._fragmentBytes += size;
      if (this._fragmentBytes > this.maxPayload) { this.close(1009, 'Too large'); return; }
      if (fin) {
        const binary = (this._fragmentOpcode || opcode) === 2;
        const body = Buffer.concat(this._fragmentParts);
        this._fragmentParts = [];
        this._fragmentOpcode = 0;
        this._fragmentBytes = 0;
        this.emit('message', body, binary);
      }
    }
  }
}
class WebSocketServer extends EventEmitter {
  constructor(opts = {}) {
    super();
    this.maxPayload = opts.maxPayload || 1_600_000;
  }
  handleUpgrade(req, socket, head, callback) {
    const secKey = req.headers['sec-websocket-key'];
    if (req.headers.upgrade?.toLowerCase() !== 'websocket' ||
      req.headers['sec-websocket-version'] !== '13' || typeof secKey !== 'string' ||
      !/^[A-Za-z0-9+/]{22}==$/.test(secKey)) { socket.destroy(); return; }
    const accept = crypto.createHash('sha1').update(secKey + GUID).digest('base64');
    socket.write('HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ' + accept + '\r\n\r\n');
    const client = new WebSocket(socket, this.maxPayload);
    callback(client);
    if (head?.length) client._parse(head);
  }
}
module.exports = { WebSocket, WebSocketServer };
