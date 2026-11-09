'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawn, execFile } = require('node:child_process');

module.exports = function management(root, refreshHttps) {
  let job = { running: false }, driver = { x64: false, x86: false };
  function detectDriver() {
    if (process.platform !== 'win32') return;
    for (const [arch, id] of [['64', '10'], ['32', '20']]) {
      execFile('reg.exe', ['query', `HKCR\\CLSID\\{5C2CD55C-92AD-4999-8666-912BD3E700${id}}\\InprocServer32`, '/ve', `/reg:${arch}`],
        { windowsHide: true }, (error, output) => { driver[arch === '64' ? 'x64' : 'x86'] = !error && /UnityCaptureFilter/i.test(output); });
    }
  }
  detectDriver();
  return {
    status() { return { supported: process.platform === 'win32', driver, job }; },
    run(kind) {
      if (process.platform !== 'win32') return { ok: false, error: 'Configuração automática disponível no Windows.' };
      if (job.running) return { ok: false, error: 'Uma configuração já está em andamento.' };
      const scripts = { wifi: 'configure-wifi.ps1', driver: 'install-webcam-driver.ps1', all: 'configure-all.ps1', remove: 'install-webcam-driver.ps1' };
      if (!scripts[kind]) return { ok: false, error: 'Configuração inválida.' };
      const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', path.join(root, 'scripts', scripts[kind])];
      if (kind === 'wifi') args.push('-NoRestart');
      if (kind === 'remove') args.push('-Remove', '-Include32Bit');
      fs.mkdirSync(path.join(root, '.local'), { recursive: true });
      const fd = fs.openSync(path.join(root, '.local', 'configuration.log'), 'a');
      job = { running: true, kind, message: 'Configurando. Aceite as solicitações do Windows que aparecerem.' };
      const child = spawn('powershell.exe', args, { cwd: root, windowsHide: true, stdio: ['ignore', fd, fd] });
      fs.closeSync(fd);
      let finished = false;
      function finish(error) {
        if (finished) return;
        finished = true;
        let httpsError;
        try { refreshHttps(); } catch (e) { httpsError = e.message; }
        job = { running: false, kind, ok: !error && !httpsError,
          message: error || httpsError || 'Configuração concluída. Para Wi-Fi, instale também o certificado no celular.' };
        detectDriver();
      }
      child.once('error', e => finish(e.message));
      child.once('exit', code => finish(code === 0 ? null : `Configuração cancelada ou falhou (código ${code}). Consulte .local/configuration.log.`));
      return { ok: true };
    }
  };
};
