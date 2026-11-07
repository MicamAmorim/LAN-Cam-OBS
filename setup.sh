#!/usr/bin/env bash
# Setup multiplataforma. No Git Bash do Windows, delega ao instalador PowerShell.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
ROOT="$PWD"
MODE="${1:-wifi}"
if [[ "$MODE" != 'wifi' && "$MODE" != 'usb' && "$MODE" != 'both' ]]; then
  echo 'Uso: bash setup.sh [wifi|usb|both] [--no-start]' >&2
  exit 2
fi
shift || true
NO_START=0
if [[ "${1:-}" == '--no-start' ]]; then NO_START=1; fi

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    command -v powershell.exe >/dev/null || { echo 'PowerShell nao encontrado.' >&2; exit 1; }
    WIN_ROOT="$(cygpath -w "$ROOT")"
    opts=()
    if (( NO_START )); then opts+=('-NoStart'); fi
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$WIN_ROOT\setup.ps1" -Mode "$MODE" "${opts[@]}"
    ;;
esac

require_node() {
  local major
  major="$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/' || true)"
  [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 20 ))
}

if ! require_node; then
  if command -v brew >/dev/null; then
    echo 'Instalando Node.js com Homebrew...'
    brew install node
  else
    echo 'Node.js >= 20 ausente. Instale de https://nodejs.org/ e execute novamente.' >&2
    exit 1
  fi
fi
require_node || { echo 'Node.js >= 20 nao encontrado.' >&2; exit 1; }
echo "Node.js: $(node -v)"

if [[ "$MODE" == 'wifi' || "$MODE" == 'both' ]]; then
  if ! command -v mkcert >/dev/null; then
    if command -v brew >/dev/null; then
      brew install mkcert
    elif command -v apt-get >/dev/null; then
      sudo apt-get update
      sudo apt-get install -y mkcert libnss3-tools
    elif command -v dnf >/dev/null; then
      sudo dnf install -y mkcert nss-tools
    else
      echo 'Instale mkcert (https://github.com/FiloSottile/mkcert) e execute novamente.' >&2
      exit 1
    fi
  fi
  mkdir -p certs
  IPS=()
  if command -v ip >/dev/null; then
    while IFS= read -r addr; do [[ -n "$addr" ]] && IPS+=("$addr"); done < <(ip -o -4 addr show scope global | awk '{split($4,a,"/"); print a[1]}')
  elif command -v ifconfig >/dev/null; then
    while IFS= read -r addr; do [[ -n "$addr" ]] && IPS+=("$addr"); done < <(ifconfig | awk '/inet / {print $2}' | grep -Ev '^(127\.|169\.254\.)' || true)
  fi
  if (( ${#IPS[@]} == 0 )); then
    echo 'Nao foi encontrado IP de rede; conecte o computador a uma LAN e repita o setup.' >&2
    exit 1
  fi
  echo "IPs locais: ${IPS[*]}"
  echo 'mkcert ira configurar uma autoridade certificadora local confiavel neste computador.'
  mkcert -install
  mkcert -cert-file certs/lan.pem -key-file certs/lan-key.pem localhost 127.0.0.1 ::1 "${IPS[@]}"
  cp "$(mkcert -CAROOT)/rootCA.pem" certs/rootCA.crt
  chmod 600 certs/lan-key.pem
  echo 'HTTPS configurado. No celular, e necessario instalar MANUALMENTE a CA publica rootCA.crt.'
fi

if [[ "$MODE" == 'usb' || "$MODE" == 'both' ]]; then
  if ! command -v adb >/dev/null; then
    if command -v brew >/dev/null; then
      brew install android-platform-tools
    elif command -v apt-get >/dev/null; then
      sudo apt-get update && sudo apt-get install -y adb
    elif command -v dnf >/dev/null; then
      sudo dnf install -y android-tools
    else
      echo 'Instale Android Platform Tools (ADB) e execute novamente.' >&2
      exit 1
    fi
  fi
  echo 'USB: conecte o Android, autorize a depuracao e execute: adb reverse tcp:8787 tcp:8787'
fi

node --check server.js
node --test tests/server.test.js
if (( NO_START )); then
  echo 'Setup concluido. Para iniciar: node server.js'
else
  echo 'Abrindo painel em http://localhost:8787 (Ctrl+C para parar).'
  exec node server.js
fi
