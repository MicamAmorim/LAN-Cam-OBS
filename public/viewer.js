(() => {
  'use strict';
  const params = new URLSearchParams(location.search);
  const key = params.get('key') || '';
  const isObs = location.pathname === '/obs';
  if (isObs) document.body.classList.add('source');
  if (params.get('fit') === 'cover') document.body.classList.add('cover');
  const video = document.getElementById('video');
  const jpeg = document.getElementById('jpeg');
  const overlay = document.getElementById('overlay');
  const ctx = jpeg.getContext('2d', { alpha: false, desynchronized: true });
  let ws, pc, pendingIce = [], reconnectTimer, watchdogTimer, remoteMode = 'webrtc', generation = 0;
  let decoding = false, lastJpegFrame = null;
  const status = text => { overlay.textContent = text; };
  const send = obj => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj)); };
  function cleanPeer() {
    generation++;
    if (pc) { pc.onicecandidate = null; pc.ontrack = null; pc.close(); pc = null; }
    pendingIce = [];
    video.srcObject = null;
  }
  function setMode(mode) {
    remoteMode = mode;
    if (mode === 'jpeg') {
      cleanPeer(); video.classList.add('hidden'); jpeg.classList.remove('hidden');
    } else {
      jpeg.classList.add('hidden'); video.classList.remove('hidden');
    }
  }
  function disconnected(text) {
    cleanPeer(); video.classList.add('hidden'); jpeg.classList.add('hidden'); status(text);
  }
  async function onOffer(msg) {
    const earlyIce = pendingIce.slice();
    cleanPeer();
    pendingIce.push(...earlyIce);
    setMode('webrtc');
    const thisGeneration = generation;
    const connection = new RTCPeerConnection({ iceServers: [], bundlePolicy: 'max-bundle' });
    pc = connection;
    connection.ontrack = event => {
      if (thisGeneration !== generation) return;
      video.srcObject = event.streams[0] || new MediaStream([event.track]);
      video.play().catch(() => {});
      status('Ao vivo · WebRTC');
    };
    connection.onicecandidate = event => { if (event.candidate) send({ type: 'ice', candidate: event.candidate }); };
    connection.onconnectionstatechange = () => {
      if (thisGeneration !== generation) return;
      if (connection.connectionState === 'failed') { status('Reconectando WebRTC...'); send({ type: 'viewer-reset' }); }
      if (connection.connectionState === 'connected') status('Ao vivo · WebRTC');
    };
    await connection.setRemoteDescription(msg.sdp);
    for (const ice of pendingIce.splice(0)) await connection.addIceCandidate(ice).catch(() => {});
    const answer = await connection.createAnswer();
    await connection.setLocalDescription(answer);
    send({ type: 'answer', sdp: connection.localDescription });
  }
  async function renderJpeg(buffer) {
    lastJpegFrame = buffer;
    if (decoding) return;
    decoding = true;
    while (lastJpegFrame) {
      const latest = lastJpegFrame; lastJpegFrame = null;
      try {
        const bitmap = await createImageBitmap(new Blob([latest], { type: 'image/jpeg' }));
        if (remoteMode !== 'jpeg') { bitmap.close(); continue; }
        if (jpeg.width !== bitmap.width || jpeg.height !== bitmap.height) { jpeg.width = bitmap.width; jpeg.height = bitmap.height; }
        ctx.drawImage(bitmap, 0, 0);
        bitmap.close();
        status('Ao vivo · USB/JPEG');
      } catch { status('Erro ao decodificar quadro'); }
    }
    decoding = false;
  }
  function connect() {
    if (!key) { disconnected('Chave de acesso ausente'); return; }
    clearTimeout(reconnectTimer);
    const proto = location.protocol === 'https:' ? 'wss' : 'ws';
    ws = new WebSocket(`${proto}://${location.host}/signal?role=viewer&key=${encodeURIComponent(key)}`);
    ws.binaryType = 'arraybuffer';
    ws.onopen = () => status('Conectado · aguardando câmera...');
    ws.onmessage = async e => {
      if (typeof e.data !== 'string') { if (e.data instanceof ArrayBuffer) renderJpeg(e.data); return; }
      let msg; try { msg = JSON.parse(e.data); } catch { return; }
      try {
        if (msg.type === 'welcome') {
          if (!msg.publisherOnline) status('Aguardando câmera...');
          else setMode(msg.mode);
        } else if (msg.type === 'publisher-online') {
          status('Câmera conectada · negociando vídeo...'); setMode(msg.mode);
        } else if (msg.type === 'publisher-offline') {
          disconnected('Câmera desconectada · aguardando...');
        } else if (msg.type === 'mode') {
          setMode(msg.mode);
          status(msg.mode === 'jpeg' ? 'Aguardando quadros JPEG...' : 'Negociando WebRTC...');
        } else if (msg.type === 'offer') {
          await onOffer(msg);
        } else if (msg.type === 'ice') {
          if (pc?.remoteDescription) await pc.addIceCandidate(msg.candidate).catch(() => {});
          else pendingIce.push(msg.candidate);
        }
      } catch (err) { status(`Erro na conexão: ${err.message}`); }
    };
    ws.onclose = () => { disconnected('Servidor desconectado · reconectando...'); reconnectTimer = setTimeout(connect, 1300); };
    ws.onerror = () => {};
  }
  connect();
  addEventListener('beforeunload', () => { clearTimeout(reconnectTimer); cleanPeer(); ws?.close(); });
})();
