# Instalador Windows (.exe)

A partir da versao 0.2.0, o LAN Cam OBS pode ser instalado sem Node.js preinstalado. O instalador inclui o runtime oficial do Node.js para Windows x64, o servidor e a interface. Nao utiliza Electron e nao depende de servico em nuvem.

## Compilar no Windows 10/11 x64

No PowerShell, na pasta do repositorio:

    git pull origin main
    .\build.bat

Alternativamente, no Git Bash do **Windows**, execute:

    bash build.sh

A compilacao instala Inno Setup 6 via winget, se necessario, baixa Node.js 24 LTS do site oficial, verifica o SHA-256 contra o manifesto SHASUMS256.txt, roda os testes e gera:

    dist\LAN-Cam-OBS-Setup-0.2.0-win-x64.exe

Para compilar sem instalar o Inno Setup automaticamente, use:

    .\scripts\build-installer.ps1 -NoInstallInno

A primeira compilacao precisa de Internet para baixar o runtime do Node.js e, possivelmente, o compilador.

## Instalar e usar

1. Execute o arquivo .exe gerado e conclua o assistente de instalacao.
2. Abra LAN Cam OBS pelo menu Iniciar. O servidor inicia em segundo plano e o navegador abre http://localhost:8787.
3. Para usar Wi-Fi no celular, execute o atalho "LAN Cam OBS - Configurar Wi-Fi HTTPS" no menu Iniciar. Isso instala ou reutiliza mkcert, gera o certificado local e reinicia o servidor. Pode solicitar permissao para instalar uma CA local no Windows.
4. No seu celular, instale MANUALMENTE o certificado publico acessivel no painel em http://IP-DO-PC:8787/local-ca.crt, apenas em dispositivos sob seu controle. A adicao de uma CA raiz traz implicacoes de seguranca.
5. Abra o endereco HTTPS completo do celular exibido no painel e inicie a camera.
6. Adicione ao OBS uma Fonte Navegador com a URL OBS exibida no painel.
7. Para parar o aplicativo, use o atalho "LAN Cam OBS - Encerrar servidor".

O instalador nao transforma o celular em um dispositivo de video do Windows; a integracao e pela fonte de navegador do OBS.

## Diretorio e desinstalacao

Instala por usuario em:

    %LOCALAPPDATA%\Programs\LAN Cam OBS

Nao exige administrador para instalar arquivos. A configuracao de HTTPS pode pedir elevacao. Em atualizacoes, preserva a chave em .local/ e os certificados em certs/. A desinstalacao (Configuracoes > Aplicativos) para o servidor e remove esses dados locais. A CA raiz instalada pelo mkcert no armazenamento de certificados do Windows NAO e removida automaticamente: remova-a manualmente se deixar de confiar nela.

Nao compartilhe seus certificados privados nem links com chaves de acesso. Evite deixar outra copia do servidor em execucao na porta 8787.

## GitHub Actions

O workflow .github/workflows/windows-installer.yml compila o instalador em um runner Windows e publica o .exe como artefato da execucao, se Actions estiver habilitado. O build local nao depende disso.

Sem certificado de assinatura de codigo, o SmartScreen pode exibir alerta de publicador desconhecido. Para distribuicao publica, uma assinatura de codigo e recomendada.

## Limites

- Windows x64; ARM64 e macOS nao cobertos pelo instalador.
- Runtime Node.js embutido; Python e .venv nao sao necessarios.
- HTTPS pela primeira vez ainda pode requerer Internet para instalar mkcert; o celular deve confiar manualmente no certificado publico.
- ADB/USB nao vem incluido no .exe; USB continua disponivel instalando ADB separadamente.
