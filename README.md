## Versão 0.4.0 — aplicativo unificado

Abra **LAN Cam OBS** no menu Iniciar. Em **Sistema**, ligue ou desligue as transmissões (o painel permanece disponível). Em **Configuração**, consulte o estado do driver e do HTTPS, instale/repare a webcam ou configure tudo. Em **LAN Cam**, encontre o QR Code do celular, os links do OBS e os controles da webcam.

A configuração do Wi-Fi ativa o HTTPS sem reiniciar o painel. Aceite as solicitações do Windows e instale o certificado público manualmente no celular. A atualização remove os atalhos auxiliares antigos. A ponte da webcam agora cria o evento de sincronização exigido pelo UnityCapture.

# LAN Cam OBS

## v0.3.0 — duas saídas no mesmo aplicativo

O LAN Cam OBS oferece agora dois modos no painel local, em **http://localhost:8787**:

- **Fonte para OBS:** mantém a fonte de navegador com WebRTC/JPEG da versão anterior.
- **Webcam para Google Meet, Zoom e Microsoft Teams:** ativa uma ponte local via JPEG e um filtro de captura DirectShow. **Não é preciso abrir o OBS.** No aplicativo de reunião, selecione **LAN Cam Webcam** no menu de câmeras.

**Antes de usar a webcam no Windows:** instale o programa, abra **Configuração → Instalar / reparar webcam** no painel LAN Cam OBS e aprove a elevação UAC uma única vez. A operação registra um componente externo MIT da biblioteca UnityCapture, cuja versão é fixada e verificada na compilação. O registro não é automático para não modificar o sistema sem consentimento. O filtro compartilhado pode ser removido em Configuração → Remover driver da webcam antes de desinstalar o aplicativo.

A câmera do celular pode continuar usando WebRTC para OBS enquanto envia quadros JPEG em paralelo para a webcam virtual, somente quando ela está ligada. Isso aumenta uso de CPU e rede, especialmente em 1080p; comece com 720p. O microfone deve ser selecionado separadamente no Meet/Zoom/Teams.

**Limitação importante:** a ponte foi integrada e os arquivos são verificáveis no repositório, mas a compatibilidade real do filtro de câmera depende do Windows e das versões dos aplicativos. Teste em um PC de destino antes de anunciar uma versão estável. Consulte [INSTALLER.md](INSTALLER.md) e [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Instalador Windows (.exe)

A versao **0.4.0** inclui um build de instalador com **Node.js embutido** (nao e necessario instalar Node no computador que recebe o programa). No Windows x64, execute `build.bat` ou, no Git Bash do Windows, `bash build.sh`. O instalador gerado ficara em `dist/LAN-Cam-OBS-Setup-0.4.0-win-x64.exe`. A primeira compilacao usa Inno Setup e baixa o Node.js oficial com verificacao SHA-256. Consulte [INSTALLER.md](INSTALLER.md) para instalacao, uso e observacoes sobre HTTPS, atualizacao e desinstalacao.

O instalador cria um único atalho LAN Cam OBS, com controles de sistema e configuração no painel. **HTTPS no celular ainda exige confiar manualmente na CA local**; esta acao nao e automatizada por motivos de seguranca.


## Instalação rápida (Windows)

Na pasta do repositório, execute **`setup.bat`** (duplo clique) ou, pelo PowerShell:

```powershell
.\setup.bat
```

O instalador verifica o **Node.js 20+**, prepara **HTTPS com mkcert** para o Wi-Fi, executa testes e inicia o servidor. Não é necessário criar `.venv`: o projeto é Node.js puro, sem dependências npm. Para usar Git Bash, execute `bash setup.sh`. Os modos `-Mode usb` e `-Mode both` também estão disponíveis. **No celular, instalar/confiar na CA pública ainda exige uma ação manual.** Veja [SETUP.md](SETUP.md) para as instruções completas e observações de segurança.

Aplicativo local, sem nuvem, para transformar o navegador do celular em uma fonte de câmera para o **OBS Studio**. Há dois transportes:

- **WebRTC, via Wi-Fi/LAN:** o servidor Node.js apenas sinaliza; o fluxo de vídeo segue entre celular e cada visualizador (inclusive OBS). Não há retranscodificação no servidor. É a melhor opção inicial para Wi-Fi.
- **JPEG/WebSocket, via USB + ADB:** quadros JPEG são enviados diretamente pelo túnel TCP `adb reverse` do celular ao PC, reproduzidos em um `canvas` na fonte de navegador. Não precisa de HTTPS nem de Wi-Fi. Tem maior consumo de CPU e banda que o WebRTC e **não é equivalente a webcam USB nativa**.

## Primeira execução no Windows

1. Instale **Node.js 20+** (https://nodejs.org/).
2. Extraia a pasta e clique em `iniciar.bat`. Alternativamente, abra PowerShell na pasta e rode:

   ```powershell
   npm start
   ```
3. No PC acesse **http://localhost:8787**. Você verá links completos e individuais para o celular, OBS e espectadores. O link do OBS não muda entre reinicializações porque a chave fica salva em `.local/state.json`.
**QR Code no painel:** abaixo de **Copiar endereço** no cartão **Abrir no celular · Wi-Fi**, o aplicativo exibe um QR Code com o link HTTPS completo da câmera. O QR é calculado localmente no navegador (sem serviço externo). Ao escanear com o celular, a URL abre diretamente. Como o QR inclui a chave de acesso, **não o compartilhe** nem exiba o painel em gravações públicas. O celular ainda precisa confiar no certificado HTTPS local.

4. Em **OBS Studio → Fontes → + → Navegador**, cole a URL de **OBS** do painel, defina **largura 1920** e **altura 1080** (ou 1280×720), desmarque **Desligar fonte quando não estiver visível** e **Atualizar navegador quando a cena se tornar ativa**. Em OBS, defina FPS 30 (ou correspondente à câmera). Inicie a câmera no celular.

**Dica de segurança:** a conexão é local, mas qualquer pessoa com o link completo e acesso à rede pode assistir. A URL contém uma chave de acesso. Evite exibi-la na transmissão e não exponha as portas na Internet/roteador. O servidor não grava vídeo.

## Modo A · Wi-Fi + WebRTC (recomendado se quiser usar site)

A captura de câmera no navegador exige origem segura. `http://IP-DO-PC` **não basta**; o navegador bloqueia `getUserMedia`. O `http://localhost` do PC não é o localhost do celular! Use HTTPS do PC, com um certificado confiável no celular.

1. Conecte celular e PC à mesma rede (idealmente **Wi-Fi 5 GHz/6 GHz**; PC via Ethernet se possível).
2. Instale mkcert no **Windows**:

   ```powershell
   winget install -e --id FiloSottile.mkcert
   ```
   **Abra novo terminal** para reconhecer o comando `mkcert`.
3. Na pasta do projeto, execute:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-https.ps1
   ```
4. **Reinicie o aplicativo** (`Ctrl+C`, `iniciar.bat` ou `npm start`). O painel exibirá o endereço HTTPS da câmera, geralmente `https://192.168.x.x:8788/phone?key=...`.
5. **No celular**, abra `http://IP-DO-PC:8787/local-ca.crt` para baixar a **CA pública** de desenvolvimento do seu computador. É normal precisar copiar o arquivo para uma pasta de documentos antes de instalar no Android. Instale esse certificado *somente* em dispositivos sob seu controle; é uma autoridade raiz confiável e tem implicações de segurança.
   - **Android:** Configurações → Segurança/Privacidade → Criptografia e credenciais → Instalar um certificado → **Certificado de CA**. O caminho pode variar. Localize o `.crt` baixado. O navegador Chrome pode precisar ser reiniciado após instalar.
   - **iPhone/iOS:** abra o arquivo no Safari e instale o perfil em **Ajustes → Perfil Baixado** (ou Geral → VPN e Gerenciamento de Dispositivos). Depois vá em **Ajustes → Geral → Sobre → Ajustes de Confiança dos Certificados** e habilite **Confiança total** para essa raiz.
6. No celular, abra a URL **HTTPS completa** do painel (com a chave) e clique **Iniciar câmera**. Permita a câmera.
7. A fonte de navegador do OBS receberá vídeo WebRTC. Não é necessário instalar app no celular.

Se a página funcionar mas a câmera falhar, verifique `window.isSecureContext` ou a mensagem na interface; confirme que o certificado é confiável, o IP corresponde ao certificado e o navegador tem permissão. Se os dois dispositivos estiverem em redes isoladas ("rede para visitantes"), o WebRTC local pode não conseguir conectar.

**Nota:** o WebRTC usa conexões de vídeo diretas entre dispositivos. Como não há TURN, é intencionalmente limitado à rede local alcançável; uma rede com isolamento ou firewall rígido pode bloquear mídia mesmo quando o painel abrir normalmente. Se o IP do PC mudar, execute `setup-https.ps1` novamente. O certificado-raiz instalado no celular pode ser o mesmo.

## Modo B · USB com Android + ADB (sem HTTPS e sem Wi-Fi)

1. Instale o **ADB** no PC:
   ```powershell
   winget install -e --id Google.PlatformTools
   ```
   Abra novo terminal após instalar.
2. No Android, habilite **Opções do desenvolvedor → Depuração USB**, conecte o cabo de dados ao PC e autorize *este computador* no alerta do celular.
3. Com o aplicativo rodando no PC, execute:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\usb-android.ps1
   ```
   (Ou rode `adb reverse tcp:8787 tcp:8787`.)
4. No **navegador do celular**, abra a URL **USB** exata do painel do PC, que começa com `http://localhost:8787/phone?key=...&transport=jpeg`. Aqui `localhost` passa pelo túnel ADB, por isso a câmera é permitida em contexto seguro, mesmo sem HTTPS.
5. Clique **Iniciar câmera** e selecione **JPEG por WebSocket**; a imagem aparece no OBS pelo endereço normal do painel.

Depois de finalizar, pode remover o túnel com `adb reverse --remove tcp:8787` e **desligar a depuração USB**, se não a utilizar para outros trabalhos. ADB é uma ferramenta de desenvolvimento privilegiada: não autorize computadores desconhecidos.

**Importante:** no modo ADB, não selecionar WebRTC. O ADB reverse encaminha WebSocket/TCP, mas **não** oferece, por si só, o caminho UDP que o WebRTC local normalmente utiliza. Para USB com WebRTC, seria necessário também estabelecer uma interface IP acessível entre os aparelhos, como tethering USB, e configurar o acesso seguro.

## Alternativa sem aplicativo (modo nativo)

Em **Android 14 QPR1 ou superior**, *alguns* fabricantes disponibilizam **Configurações USB → Webcam**. Se seu celular mostrar essa opção: conecte via cabo de dados, escolha **Webcam** nas opções USB e no OBS selecione **Dispositivo de captura de vídeo**, usando o celular. É uma boa primeira tentativa para conexão cabeada. Nem todos os fabricantes expõem essa função, mesmo em versões Android recentes.

Em **Windows 11 + Android 10+**, a Microsoft também disponibiliza **Usar como câmera conectada** nas configurações de Dispositivos Móveis, via Vincular ao Windows. Dependendo da compatibilidade, pode ser um caminho sem programar aplicativo; sua conexão é por Wi-Fi.

## Ajustes de desempenho

- Priorize **720p/30 FPS**, câmera traseira e boa iluminação para começar. Só aumente para 1080p se a imagem e conexão estiverem estáveis.
- Prefira PC via cabo Ethernet e celular no Wi-Fi de 5/6 GHz; evite guest Wi-Fi, repetidores ruins e economia de bateria agressiva.
- O modo JPEG manda quadros independentes, evitando longos buffers, mas custa mais CPU/banda; em USB a qualidade JPEG cai ou sobe com o navegador, e latência real deve ser medida.
- Cada novo espectador WebRTC recebe sua própria conexão do celular (sem servidor SFU). É adequado para **OBS e alguns espectadores**, não para dezenas de pessoas.
- O aplicativo não transmite microfone nesta versão. Recomenda-se captar áudio separadamente no PC/OBS.
- A página da câmera precisa ficar aberta, com celular **desbloqueado**; há tentativa de ativar a API de prevenção de suspensão da tela.
- Se quiser preencher a tela do OBS cortando bordas, acrescente `&fit=cover` à URL de OBS. Sem isso, a imagem inteira fica visível com barras quando necessário.

## Privacidade e limitações

- Sem armazenamento de mídia. O servidor local recebe sinais WebRTC; apenas no modo JPEG/ADB o vídeo atravessa o servidor e é entregue aos espectadores.
- Não abre portas no roteador. O aplicativo **escuta** nas portas `8787` (HTTP) e `8788` (HTTPS, se configurado); configure o Firewall do Windows para permitir somente **redes privadas**.
- Certificados e dados locais são ignorados pelo Git. Nunca publique os arquivos em `certs/`, `.local/` ou certificados privados do mkcert (`rootCA-key.pem`).
- Embora seja funcional no nível de código, a imagem real no OBS/Android/iOS depende de teste no dispositivo e pode requerer ajustes para limitações de WebRTC do navegador/versão do OBS.

## Desenvolvimento

```powershell
npm run check
npm test
```

Estrutura:

```text
server.js                  HTTP/HTTPS, sinalização e retransmissão JPEG
public/index.html          Painel local de gerenciamento
public/phone.*             Captura de câmera e emissão WebRTC/JPEG
public/viewer.*            Receptor para OBS e visualizadores
scripts/setup-https.ps1    Certificado local
scripts/usb-android.ps1    Ponte USB com ADB
```

### Links oficiais
- [MDN: getUserMedia / contextos seguros](https://developer.mozilla.org/en-US/docs/Web/API/MediaDevices/getUserMedia)
- [OBS: Browser Source](https://obsproject.com/kb/Browser-Source)
- [mkcert: certificados locais](https://github.com/FiloSottile/mkcert)
- [Android: usar dispositivo como webcam](https://source.android.com/docs/core/camera/webcam)
- [Microsoft: câmera conectada](https://support.microsoft.com/pt-br/windows/apps/phonelink/use-your-mobile-device-s-camera)

> **Sem dependências npm:** o servidor inclui um WebSocket pequeno em `lib/ws-lite.js`. Basta o Node.js e `npm start`; não há downloads de pacotes na primeira execução.
