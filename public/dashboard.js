(async () => {
  const byId = id => document.getElementById(id);
  const setLink = (id, url) => {
    const a = byId(id); a.href = url; a.textContent = url;
  };
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
    if (ip) { setLink('phoneLink', wifi); setLink('viewLink', view); }
    byId('httpsHint').textContent = cfg.httpsReady ? 'HTTPS configurado. Se aparecer aviso, instale a CA local no celular.' : 'HTTPS ainda indisponível. Execute o script de configuração e reinicie o servidor.';
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
    async function status() {
      try {
        const s = await (await fetch('/api/status', { cache: 'no-store' })).json();
        byId('status').textContent = s.connected ? `Câmera conectada · ${s.mode.toUpperCase()}` : 'Aguardando câmera';
        byId('status').classList.toggle('offline', !s.connected);
        byId('count').textContent = `${s.viewers} visualizador(es)`;
      } catch { byId('status').textContent = 'Servidor indisponível'; }
    }
    await status(); setInterval(status, 2000);
  } catch (e) { document.querySelector('main').insertAdjacentHTML('afterbegin', `<p class="hint warn">${e.message}</p>`); }
})();
