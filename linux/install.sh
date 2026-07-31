#!/usr/bin/env bash
#
# install.sh — ponto de entrada para configurar um notebook Linux (Ubuntu).
#
# Uso:
#   sudo ./install.sh              # roda todos os módulos (exceto --packages)
#   sudo ./install.sh --packages   # roda SÓ a restauração de pacotes (opcional)
#   sudo ./install.sh --dry-run    # mostra o que faria sem tocar no sistema
#   sudo ./install.sh --module 10-memory,20-camera
#
# Idempotente: pode rodar quantas vezes quiser.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./lib.sh

MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALL_MODULES=(10-memory 20-camera 30-peripherals)
PACKAGES_MODULE="40-packages"

SELECTED=""
RUN_PACKAGES=0
DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --packages) RUN_PACKAGES=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    --module)   SELECTED="${2:?--module exige uma lista}"; shift 2 ;;
    -h|--help)
      awk 'NR>1 && /^#/{sub(/^#[[:space:]]?/,""); print; next} NR>1{exit}' "$0"
      printf '\nMódulos disponíveis: %s\n' "${ALL_MODULES[*]} ${PACKAGES_MODULE}"
      exit 0 ;;
    *) die "argumento desconhecido: $1 (use --help)" ;;
  esac
done
export DRY_RUN

if [ "$DRY_RUN" = "1" ]; then
  log "${c_yellow}MODO DRY-RUN — nada será alterado.${c_off}"
fi

run_module() {
  local mod="$1"
  local script="${MODULES_DIR}/${mod}.sh"
  [ -f "$script" ] || die "módulo não encontrado: ${mod} (${script})"
  echo
  printf '%s═══ %s ═══%s\n' "$c_blue" "$mod" "$c_off"
  DRY_RUN="$DRY_RUN" bash "$script"
}

if [ "$RUN_PACKAGES" = "1" ]; then
  run_module "$PACKAGES_MODULE"
  exit 0
fi

if [ -n "$SELECTED" ]; then
  IFS=',' read -ra mods <<<"$SELECTED"
  for m in "${mods[@]}"; do run_module "$m"; done
  exit 0
fi

for m in "${ALL_MODULES[@]}"; do run_module "$m"; done

echo
ok "Configuração de base concluída."
echo
printf '  Para restaurar os apps também (opcional, demorado):\n'
printf '  %s  sudo ./install.sh --packages%s\n' "$c_dim" "$c_off"
printf '  Para diagnosticar a câmera:\n'
printf '  %s  canon-webcam --check%s\n' "$c_off"
echo
