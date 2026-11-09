# Instalação e configuração — 0.4.2

Para usar o programa no Windows x64, prefira o [instalador da pré-release v0.4.2-rc.1](https://github.com/MicamAmorim/LAN-Cam-OBS/releases/tag/v0.4.2-rc.1). Ele inclui Node.js e cria um único atalho **LAN Cam OBS**. Abra **Configuração** no painel para preparar Wi-Fi e webcam; abra **LAN Cam** para o QR Code e links do OBS. O certificado público no celular continua sendo uma etapa manual.

As correções de 0.4.1/0.4.2 evitam sobrescrever DLLs idênticas em uso, resolvem o executável real do mkcert e aguardam o regsvr32 com código de saída verificável. Veja [INSTALLER.md](INSTALLER.md) para diagnóstico e atualização.

**Limitação conhecida:** a câmera está registrada e listada no DirectShow, mas sua presença na lista do Meet/Edge ainda não foi confirmada. A pré-release não garante essa compatibilidade; [notas da versão](docs/releases/0.4.2.md).

Os procedimentos abaixo são para executar o repositório diretamente. Eles não são necessários para quem usa o instalador `.exe`.

# Preparação pelo código-fonte

O LAN Cam OBS usa **Node.js**, não Python; por isso **não necessita de `python`, `pip` ou `.venv`**. O projeto também não tem dependências npm para instalar.

## Windows 10/11 — scripts de desenvolvimento

Na pasta do projeto, dê dois cliques em **`setup.bat`** ou execute no PowerShell:

```powershell
.\setup.bat
# ou:
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

O instalador verifica o Node.js 20+, instala o Node LTS (se necessário) com **winget**, instala o **mkcert**, cria o certificado HTTPS para os IPs locais, executa os testes e inicia o servidor. Uma janela do Windows pode solicitar autorização para instalar ou confiar no certificado. Caso não exista `winget`, será necessário instalar o *App Installer* antes. Para instalação apenas, sem iniciar o servidor, use `.\setup.bat -NoStart`.

Também é possível usar Git Bash:

```bash
bash setup.sh
```

### Escolher modo de transmissão

```powershell
.\setup.bat -Mode wifi     # padrão: WebRTC/Wi-Fi + HTTPS
.\setup.bat -Mode usb      # instala ADB; USB/JPEG, sem HTTPS
.\setup.bat -Mode both     # configura ambos
.\setup.bat -NoStart       # não inicia servidor ao terminar
```

No modo USB, conecte o Android por cabo de dados, habilite depuração USB, autorize o computador e, com o servidor iniciado, execute `powershell -File .\scripts\usb-android.ps1`. O instalador não habilita a depuração no celular automaticamente.

## macOS / Linux

```bash
bash setup.sh [wifi|usb|both]
# apenas instalar e testar:
bash setup.sh wifi --no-start
```

O script verifica Node.js 20+; pode instalar pelo Homebrew. Para o mkcert, usa Homebrew, apt ou dnf quando disponíveis. Em sistemas não suportados, mostra como instalar manualmente. Para conexão USB, verifica/instala ADB onde houver suporte de pacote.

## Etapa que continua manual (necessária para Wi-Fi)

No **celular**, abra a URL de download da CA pública informada no painel `http://localhost:8787` do computador (acessada no celular pelo IP do PC, como `http://192.168.x.x:8787/local-ca.crt`) e instale o certificado como autoridade confiável **somente no seu aparelho**. Depois abra a URL **HTTPS com chave** indicada no painel para iniciar a câmera. Essa confiança de certificado não pode, nem deve, ser instalada silenciosamente no celular.

**Segurança:** os arquivos de certificado privados em `certs/` e a chave de acesso em `.local/` não devem ser enviados ao Git ou compartilhados. O setup não altera o roteador nem publica o servidor na Internet. Se o endereço IP do PC mudar, execute o setup novamente para gerar um certificado válido para o novo IP. Dependendo do firewall do Windows, você deverá autorizar manualmente o Node.js **apenas em redes privadas**.

Após a instalação, nas próximas execuções basta usar `iniciar.bat` (Windows) ou `node server.js` (macOS/Linux).