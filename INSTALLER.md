# Instalador Windows — 0.4.2

O instalador inclui Node.js e a interface local. Não requer Node.js pré-instalado, Python ou dependências npm. O destino é Windows 10/11 x64; ARM64, macOS e Linux não são cobertos por este pacote.

## Baixar e instalar

1. Abra a [release v0.4.2-rc.1](https://github.com/MicamAmorim/LAN-Cam-OBS/releases/tag/v0.4.2-rc.1) e baixe `LAN-Cam-OBS-Setup-0.4.2-win-x64.exe`.
2. Conclua o assistente e abra **LAN Cam OBS** no menu Iniciar.
3. Em **Configuração**, instale/repare a webcam e configure o Wi-Fi, ou use **Configurar tudo**. Aceite as solicitações do Windows quando concordar com as alterações.
4. No celular, instale manualmente a CA pública indicada no painel, apenas em um aparelho sob seu controle.
5. Em **LAN Cam**, escaneie o QR Code, abra o endereço HTTPS e inicie a câmera no celular. Copie a URL de fonte de navegador para o OBS.
6. Para testar a saída de webcam, ative **Webcam** e procure **LAN Cam Webcam** no aplicativo de destino. A compatibilidade com Meet/Edge ainda está pendente; veja a seção abaixo.

**Sistema → Desligar sistema** interrompe transmissões e a ponte da webcam. O painel continua disponível para religar. Fechar a aba do painel não encerra o servidor.

## Conferir o download

Baixe também o arquivo `.exe.sha256` da release. Compare o hash publicado com:

```powershell
Get-FileHash .\LAN-Cam-OBS-Setup-0.4.2-win-x64.exe -Algorithm SHA256
```

O instalador não tem assinatura de código; o Windows pode identificar o publicador como desconhecido.

## Atualizar e desinstalar

O destino padrão é `%LOCALAPPDATA%\Programs\LAN Cam OBS`. A instalação dos arquivos é por usuário. O registro do driver requer administrador; a preparação de HTTPS também pode solicitar autorização.

Ao atualizar, o instalador usa seu próprio script novo para encerrar o runtime dedicado e esperar sua saída, mesmo sem `.local/server.pid`. Não encerra outros runtimes Node pelo nome. A atualização preserva `.local/` e `certs/` e remove os atalhos auxiliares antigos.

O driver registrado permanece em `%ProgramData%\LAN Cam Webcam\Driver`. Para removê-lo, use **Configuração → Remover driver da webcam** antes de desinstalar o aplicativo. DLLs em uso podem exigir fechar os aplicativos de câmera. O filtro compartilha identificadores com UnityCapture; considere outras instalações antes de registrar ou remover esse componente.

A desinstalação em **Configurações do Windows → Aplicativos** remove os dados locais e certificados da pasta do aplicativo. A CA confiável instalada pelo mkcert no Windows não é removida automaticamente.

## Diagnóstico

| Sintoma | Comportamento e ação |
| --- | --- |
| `node.exe`: acesso negado durante atualização | A versão 0.4.1+ encerra o runtime pelo caminho do executável e aguarda sua liberação. Se persistir, feche o LAN Cam e repita; não ignore o arquivo no instalador. |
| DLL da webcam em uso | DLLs idênticas são preservadas desde 0.4.1. Para trocar uma DLL diferente, feche os aplicativos que usam a webcam e repita. |
| mkcert: nenhum aplicativo associado | A versão 0.4.1+ resolve o binário real do WinGet, em vez de executar seu link simbólico. |
| regsvr32 falhou com código vazio | Corrigido em 0.4.2: o script aguarda o processo e lê seu `ExitCode`. Um erro numérico diferente de zero ainda deve ser investigado. |
| HTTPS ativo, mas celular não conecta | Confira confiança na CA, endereço IP, mesma rede e permissões de câmera. Se o IP mudou, use **Configurar / atualizar Wi-Fi**. |
| Webcam registrada, mas ausente no Meet/Edge | **Pendência conhecida desta pré-release.** Encerre completamente o navegador quando puder sair da reunião e teste novamente. A causa ainda não foi confirmada. Registro e captura DirectShow não garantem enumeração no navegador. |

Consulte os detalhes no painel e `.local/configuration.log`. A ponte grava em `.local/webcam-bridge.log`. Não publique chaves de acesso nem certificados privados ao compartilhar um diagnóstico.

## Compilar

No PowerShell, a partir da branch que contém esta versão:

```powershell
git switch feature/dual-camera-modes
git pull --ff-only origin feature/dual-camera-modes
.\build.bat
```

Alternativamente, no Git Bash do Windows: `bash build.sh`. Para impedir instalação automática do Inno Setup:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-installer.ps1 -NoInstallInno
```

O build verifica o SHA-256 do Node.js oficial e os blobs dos drivers UnityCapture fixados em revisão, valida sintaxe, executa os testes do servidor e as regressões Windows, e gera `dist\LAN-Cam-OBS-Setup-0.4.2-win-x64.exe`. A primeira compilação requer Internet para as dependências. O workflow `.github/workflows/windows-installer.yml` também compila no Windows e disponibiliza o executável como artefato da execução.

## Publicar

Com Git e GitHub CLI autenticados, branch sincronizada e árvore limpa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\publish-release.ps1
```

O script lê a versão de `package.json`, usa as notas em `docs/releases/<versão>.md`, recompila com os testes, gera `.sha256` e publica `v<versão>-rc.1` como pré-release. Uma release existente não é sobrescrita. Para outro candidato, use `-Candidate 2`. O parâmetro `-Stable` publica `v<versão>` e deve ser usado somente depois de validar as pendências de compatibilidade.

## Limites

- O áudio não é transmitido; selecione o microfone no aplicativo de destino.
- O componente principal do driver é x64. Para registrar x86 também, execute `scripts\install-webcam-driver.ps1 -Include32Bit` com os arquivos do driver presentes.
- ADB não é incluído; USB/Android depende de instalação e autorização próprias.
- O celular deve confiar manualmente na CA para usar HTTPS; não há configuração silenciosa dessa confiança.
- O servidor não configura o roteador. Permita acesso somente na sua rede privada e não compartilhe URLs com chave, `.local/`, `certs/` ou a CA privada.

Veja [notas da versão](docs/releases/0.4.2.md), [SETUP.md](SETUP.md) e [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
