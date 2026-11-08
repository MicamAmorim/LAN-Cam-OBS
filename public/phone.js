(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const params = new URLSearchParams(location.search);
  const key = params.get('key') || '';
  const modeEl = $('mode');
  if (params.get('transport') === 'jpeg' || (location.protocol === 'http:' && ['localhost', '127.0.0.1'].includes(location.hostname))) modeEl.value = 'jpeg';
  const pcMap = new Map();
  const pending = new Map();
  let stream, socket, active = false, connecting = false, wakeLock, jpegTimer, viewerCount = 0;
  let sendMode = 'webrtc', jpegEpoch = 0, webcamEnabled = false;
  const setStatus = (text, online = false) => { $('status').textContent = text; $('status').classList.toggle('offline', !online); };
  const setError = text => { $('error').textContent = text || ''; };
  const send = msg => { if (socket?.readyState === WebSocket.OPEN) socket.send(JSON.stringify(msg)); };
  const setCount = n => { viewerCount = Math.max(0, n); $('viewers').textContent = `${viewerCount} visualizador(es)`; };
  const updateButtons = () => {
    $('start').disabled = active; $('stop').disabled = !active; $('flip').disabled = !active;
    $('quality').disabled = active; $('mode').disabled = active;
  };
  const clearPeer = id => { const pc = pcMap.get(id); if (pc) { pc.onicecandidate = null; pc.close(); } pcMap.delete(id); pending.delete(id); };
  const clearPeers = () => { for (const id of pcMap.keys()) clearPeer(id); };
  if (!key) setError('URL sem chave de acesso. Copie o endereço completo no painel do computador.');
  $('secureHint').textContent = window.isSecureContext
    ? 'Contexto seguro detectado: o navegador pode solicitar acesso à câmera.'
    : 'ATENÇÃO: neste endereço a câmera pode estar bloqueada. Use HTTPS confiável no Wi-Fi ou http://localhost via ADB reverse no Android.';
  async function startCamera() {
    if (active || connecting) return;
    setError(''); connecting = true; $('start').disabled = true;
    try {
      if (!key) throw new Error('Chave de acesso ausente.');
      if (!navigator.mediaDevices?.getUserMedia) throw new Error('A câmera não está disponível. No Wi-Fi, instale e confie no certificado HTTPS; no USB use localhost via ADB.');
      const quality = $('quality').value;
      const width = quality === '1080' ? 1920 : quality === '480' ? 854 : 1280;
      const height = quality === '1080' ? 1080 : quality === '480' ? 480 : 720;
      const fps = quality === '480' ? 24 : 30;
      try {
        stream = await navigator.mediaDevices.getUserMedia({ audio: false, video: { facingMode: { ideal: $('camera').value }, width: { ideal: width }, height: { ideal: height }, frameRate: { ideal: fps, max: fps } } });
      } catch (err) {
        if (err.name === 'OverconstrainedError') stream = await navigator.mediaDevices.getUserMedia({ audio: false, video: true });
        else throw err;
      }
      $('preview').srcObject = stream;
      await $('preview').play().catch(() => {});
      $('placeholder').classList.add('hidden');
      active = true; sendMode = modeEl.value;
      updateButtons(); setStatus('Conectando ao servidor...');
      tryWakeLock();
      openSocket();
    } catch (e) {
      setError(`Não foi possível iniciar: ${e.message}`);
      stopCamera();
    } finally { connecting = false; updateButtons(); }
  }
  async function tryWakeLock() {
    try { if ('wakeLock' in navigator && active) wakeLock = await navigator.wakeLock.request('screen'); } catch (_) {}
  }
  document.addEventListener('visibilitychange', () => { if (!document.hidden && active) tryWakeLock(); });
  function stopCamera() {
    active = false;
    jpegEpoch++; webcamEnabled = false; clearTimeout(jpegTimer); clearPeers(); pending.clear();
    if (socket) { socket.onclose = null; socket.close(); socket = null; }
    if (stream) { for (const track of stream.getTracks()) track.stop(); stream = null; }
    if (wakeLock) { wakeLock.release().catch(() => {}); wakeLock = null; }
    $('preview').srcObject = null;
    $('placeholder').classList.remove('hidden');
    setCount(0); setStatus('Câmera desligada'); updateButtons();
  }
  const socketUrl = () => `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/signal?role=phone&key=${encodeURIComponent(key)}`;
  function openSocket() {
    if (!active) return;
    socket = new WebSocket(socketUrl());
    socket.onopen = () => setStatus('Câmera ligada · conectando espectadores', true);
    socket.onmessage = async event => {
      if (typeof event.data !== 'string') return;
      let msg; try { msg = JSON.parse(event.data); } catch { return; }
      if (!active) return;
      try {
        if (msg.type === 'welcome') {
          send({ type: 'mode', mode: sendMode });
          setCount(msg.viewers?.length || 0);
          webcamEnabled = Boolean(msg.webcamEnabled);
          if (sendMode === 'webrtc') for (const id of msg.viewers || []) createOffer(id);
          if (sendMode === 'jpeg' || webcamEnabled) startJpeg();
          setStatus(`Transmitindo · ${sendMode === 'jpeg' ? 'USB/JPEG' : 'WebRTC'}`, true);
        } else if (msg.type === 'webcam') {
          webcamEnabled = Boolean(msg.enabled);
          if (sendMode === 'jpeg' || webcamEnabled) startJpeg();
          else { jpegEpoch++; clearTimeout(jpegTimer); }
        } else if (msg.type === 'viewer-joined') {
          setCount(viewerCount + 1);
          if (sendMode === 'webrtc') createOffer(msg.id);
        } else if (msg.type === 'viewer-left') {
          setCount(viewerCount - 1); clearPeer(msg.id);
        } else if (msg.type === 'answer' && pcMap.has(msg.from)) {
          const pc = pcMap.get(msg.from);
          await pc.setRemoteDescription(msg.sdp);
          await flushIce(msg.from, pc);
        } else if (msg.type === 'ice' && pcMap.has(msg.from)) {
          const pc = pcMap.get(msg.from);
          if (pc.remoteDescription) await pc.addIceCandidate(msg.candidate).catch(() => {});
          else pending.get(msg.from)?.push(msg.candidate);
        } else if (msg.type === 'viewer-reset' && sendMode === 'webrtc') {
          clearPeer(msg.from); createOffer(msg.from);
        }
      } catch (err) { setError(`Sinalização: ${err.message}`); }
    };
    socket.onclose = () => {
      if (!active) return;
      clearPeers(); setCount(0); clearTimeout(jpegTimer);
      setStatus('Conexão interrompida · reconectando');
      setTimeout(() => { if (active) openSocket(); }, 1300);
    };
    socket.onerror = () => {};
  }
  async function flushIce(id, pc) {
    for (const candidate of pending.get(id) || []) await pc.addIceCandidate(candidate).catch(() => {});
    pending.set(id, []);
  }
  async function createOffer(id) {
    if (!active || !stream || pcMap.has(id)) return;
    const pc = new RTCPeerConnection({ iceServers: [], bundlePolicy: 'max-bundle' });
    pcMap.set(id, pc); pending.set(id, []);
    for (const track of stream.getTracks()) pc.addTrack(track, stream);
    pc.onicecandidate = event => { if (event.candidate) send({ type: 'ice', to: id, candidate: event.candidate }); };
    pc.onconnectionstatechange = () => {
      if (pc.connectionState === 'failed' && pcMap.get(id) === pc) {
        clearPeer(id); setTimeout(() => { if (active && sendMode === 'webrtc') createOffer(id); }, 900);
      }
    };
    try { const offer = await pc.createOffer(); await pc.setLocalDescription(offer); send({ type: 'offer', to: id, sdp: pc.localDescription }); }
    catch (err) { clearPeer(id); setError(`WebRTC: ${err.message}`); }
  }
  function startJpeg() {
    clearTimeout(jpegTimer);
    const epoch = ++jpegEpoch;
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d', { alpha: false, desynchronized: true });
    const desiredInterval = $('quality').value === '480' ? 42 : 34;
    const tick = () => {
      if (!active || epoch !== jpegEpoch || (sendMode !== 'jpeg' && !webcamEnabled) || socket?.readyState !== WebSocket.OPEN) return;
      const startedAt = performance.now();
      if ((viewerCount || webcamEnabled) && socket.bufferedAmount < 800_000 && $('preview').videoWidth) {
        const source = $('preview');
        const limit = $('quality').value === '1080' ? 1600 : $('quality').value === '480' ? 854 : 1280;
        const scale = Math.min(1, limit / source.videoWidth);
        const w = Math.max(1, Math.round(source.videoWidth * scale));
        const h = Math.max(1, Math.round(source.videoHeight * scale));
        if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
        ctx.drawImage(source, 0, 0, w, h);
        canvas.toBlob(blob => {
          if (epoch !== jpegEpoch) return;
          if (blob && active && socket?.readyState === WebSocket.OPEN && socket.bufferedAmount < 800_000) socket.send(blob);
          jpegTimer = setTimeout(tick, Math.max(5, desiredInterval - (performance.now() - startedAt)));
        }, 'image/jpeg', 0.70);
      } else jpegTimer = setTimeout(tick, 120);
    };
    tick();
  }
  $('start').onclick = startCamera;
  $('stop').onclick = stopCamera;
  $('flip').onclick = async () => {
    const wasActive = active;
    $('camera').value = $('camera').value === 'user' ? 'environment' : 'user';
    if (wasActive) { stopCamera(); await startCamera(); }
  };
  addEventListener('beforeunload', stopCamera);
})();
