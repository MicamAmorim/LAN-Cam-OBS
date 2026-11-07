#!/usr/bin/env bash
# Wrapper Git Bash para compilar o instalador no Windows.
set -euo pipefail
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) echo "O instalador .exe deve ser compilado no Windows com Inno Setup." >&2; exit 1 ;;
esac
cd "$(dirname "$0")"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "./scripts/build-installer.ps1" "$@"
