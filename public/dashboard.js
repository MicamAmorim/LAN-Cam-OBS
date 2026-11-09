(async () => {
  const byId = id => document.getElementById(id);
  const setLink = (id, url) => {
    const a = byId(id); a.href = url; a.textContent = url;
  };
  // QR local: a URL com chave nunca e enviada a servicos de terceiros.
  const renderPhoneQr = (url) => {
    const wrapper = byId('phoneQrWrap');
    try {
      if (typeof qrcode !== 'function') throw new Error('Biblioteca de QR Code indisponível.');
      const code = qrcode(0, 'M');
      code.addData(url);
      code.make();
      const count = code.getModuleCount();
      const margin = 4; // zona silenciosa obrigatoria do QR.
      const moduleSize = 7;
      const pixels = (count + margin * 2) * moduleSize;
      const canvas = byId('phoneQr');
      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('Canvas indisponível no navegador.');
      canvas.width = pixels;
      canvas.height = pixels;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, pixels, pixels);
      ctx.fillStyle = '#000000';
      for (let y = 0; y < count; y++) {
        for (let x = 0; x < count; x++) {
          if (code.isDark(y, x)) ctx.fillRect((x + margin) * moduleSize, (y + margin) * moduleSize, moduleSize, moduleSize);
        }
      }
      wrapper.classList.remove('hidden');
    } catch (error) {
      byId('phoneQrError').textContent = 'QR Code indisponível: utilize o botão Copiar endereço.';
      byId('phoneQrError').classList.remove('hidden');
      console.error('QR Code local:', error);
    }
  };
  document.querySelectorAll('[data-screen]').forEach(button => {
    button.onclick = () => {
      document.querySelectorAll('.app-screen').forEach(screen => screen.classList.toggle('hidden', screen.id !== 'screen-' + button.dataset.screen));
      document.querySelectorAll('[data-screen]').forEach(tab => {
        const selected = tab === button;
        tab.classList.toggle('selected', selected);
        tab.setAttribute('aria-pressed', String(selected));
      });
    };
  });
  async function managementAction(endpoint, messageId) {
    try {
      const response = await fetch(endpoint, { method: 'POST', headers: { 'X-LAN-CAM': 'dashboard' } });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Não foi possível executar a ação.');
      byId(messageId).textContent = endpoint.includes('/setup/') ? 'Preparando configuração. Aceite as solicitações do Windows.' : 'Estado atualizado.';
    } catch (error) { byId(messageId).textContent = error.message; }
  }
  byId('systemStart').onclick = () => managementAction('/api/system/start', 'systemMessage');
  byId('systemStop').onclick = () => managementAction('/api/system/stop', 'systemMessage');
  document.querySelectorAll('[data-setup]').forEach(button => {
    button.onclick = async () => {
      document.querySelectorAll('[data-setup]').forEach(b => { b.disabled = true; });
      await managementAction('/api/setup/' + button.dataset.setup, 'setupMessage');
    };
  });
  let wasConfiguring = false;
  async function setupStatus() {
    const response = await fetch('/api/setup', { cache: 'no-store' });
    if (!response.ok) throw new Error('Não foi possível consultar a configuração.');
    const info = await response.json();
    byId('driverSetupStatus').textContent = info.driver.x64 && info.driver.x86 ? 'Configurado · driver 64 e 32 bits registrado.' : info.driver.x64 ? 'Configurado · driver 64 bits registrado (32 bits é opcional).' : 'Webcam ainda não configurada.';
    byId('wifiSetupStatus').textContent = info.httpsReady ? 'HTTPS ativo. Se a rede mudou, atualize a configuração.' : 'HTTPS indisponível. Configure para conectar o celular por Wi-Fi.';
    document.querySelectorAll('[data-setup]').forEach(b => { b.disabled = !info.supported || info.job.running; });
    if (info.job.message) byId('setupMessage').textContent = info.job.message;
    if (wasConfiguring && !info.job.running && info.job.ok) {
      byId('httpsHint').textContent = info.httpsReady ? 'HTTPS configurado. Instale a CA local no celular.' : 'HTTPS indisponível. Configure o Wi-Fi.';
    }
    wasConfiguring = info.job.running;
  }
  try {
    const r = await fetch('/api/config', { cache: 'no-store' });
    if (!r.ok) throw new Error('Este painel de configuração só abre no próprio computador.');
    const cfg = await r.json();
    const ip = cfg.ips.find(x => x.startsWith('192.168.')) || cfg.ips.find(x => x.startsWith('10.')) || cfg.ips[0];
    const query = '?key=' + encodeURIComponent(cfg.key);
    const obs = `http://localhost:${cfg.httpPort}/obs${query}`;
    const usb = `http://localhost:${cfg.httpPort}/phone${query}&transport=jpeg`;
    const wifi = ip ? `https://${ip}:${cfg.httpsPort}/phone${query}` : '(IP de rede não encontrada)';
    const view = ip ? `https://${ip}:${cfg.httpsPort}/view${query}` : obs.replace('/obs', '/view');
    setLink('obsLink', obs); setLink('usbLink', usb);
    if (ip) { setLink('phoneLink', wifi); setLink('viewLink', view); renderPhoneQr(wifi); }
    byId('httpsHint').textContent = cfg.httpsReady ? 'HTTPS configurado. Se aparecer aviso, instale a CA local no celular.' : 'HTTPS ainda indisponível. Abra Configuração e clique em Configurar Wi-Fi.';
    if (ip) {
      byId('certLink').href = `http://${ip}:${cfg.httpPort}/local-ca.crt`;
      byId('certLink').textContent = `http://${ip}:${cfg.httpPort}/local-ca.crt`;
    }
    document.querySelectorAll('button[data-copy]').forEach(button => {
      button.onclick = async () => {
        const value = byId(button.dataset.copy).href;
        try { await navigator.clipboard.writeText(value); button.textContent = 'Copiado!'; }
        catch { window.prompt('Copie o endereço:', value); }
        setTimeout(() => { button.textContent = button.dataset.copy === 'obsLink' ? 'Copiar URL do OBS' : 'Copiar endereço'; }, 1400);
      };
    });
    const obsTab = byId('selectObs'), webcamTab = byId('selectWebcam');
    function setOutputMode(mode) {
      const isWebcam = mode === 'webcam';
      obsTab.classList.toggle('selected', !isWebcam);
      webcamTab.classList.toggle('selected', isWebcam);
      obsTab.setAttribute('aria-pressed', String(!isWebcam));
      webcamTab.setAttribute('aria-pressed', String(isWebcam));
      byId('obsSummary').classList.toggle('hidden', isWebcam);
      byId('webcamSummary').classList.toggle('hidden', !isWebcam);
    }
    obsTab.onclick = () => setOutputMode('obs');
    webcamTab.onclick = () => setOutputMode('webcam');
    async function webcamAction(action) {
      byId('webcamStart').disabled = true;
      byId('webcamStop').disabled = true;
      try {
        const resp = await fetch('/api/webcam/' + action, {
          method: 'POST', headers: { 'X-LAN-CAM': 'dashboard' }
        });
        const body = await resp.json();
        if (!resp.ok) throw new Error(body.error || 'Falha ao alterar a webcam.');
        await status();
      } catch (e) {
        byId('webcamStatus').textContent = e.message;
        byId('webcamStart').disabled = false;
      }
    }
    byId('webcamStart').onclick = () => webcamAction('start');
    byId('webcamStop').onclick = () => webcamAction('stop');
    async function status() {
      try {
        const s = await (await fetch('/api/status', { cache: 'no-store' })).json();
        byId('status').textContent = s.connected ? `Câmera conectada · ${s.mode.toUpperCase()}` : 'Aguardando câmera';
        byId('status').classList.toggle('offline', !s.connected);
        byId('count').textContent = `${s.viewers} visualizador(es)`;
        byId('systemStatus').textContent = s.systemEnabled ? 'Sistema ligado · pronto para conectar o celular.' : 'Sistema desligado · transmissões interrompidas.';
        byId('systemStart').disabled = s.systemEnabled;
        byId('systemStop').disabled = !s.systemEnabled;
        const webcam = s.webcam || {};
        byId('webcamStart').disabled = !s.systemEnabled || !webcam.supported || !webcam.available || Boolean(webcam.active);
        byId('webcamStop').disabled = !webcam.active;
        byId('webcamStatus').textContent = webcam.connected
          ? 'Ponte conectada. No Meet/Zoom/Teams, selecione LAN Cam Webcam.'
          : webcam.active ? 'Iniciando a ponte local. Selecione LAN Cam Webcam no aplicativo de reunião.'
            : webcam.supported ? 'Desativada. Instale o driver na área Configuração antes do primeiro uso.'
              : 'A webcam nativa está disponível apenas no Windows.';
      } catch { byId('status').textContent = 'Servidor indisponível'; byId('systemStatus').textContent = 'Servidor indisponível. Reabra LAN Cam OBS pelo menu Iniciar.'; }
    }
    await status(); await setupStatus(); setInterval(() => { status(); setupStatus().catch(() => {}); }, 2000);
  } catch (e) { document.querySelector('main').insertAdjacentHTML('afterbegin', `<p class="hint warn">${e.message}</p>`); }
})();
