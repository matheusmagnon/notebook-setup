#!/usr/bin/env bash
# Módulo: periféricos — mouse Logitech (LogiOps) e ferramentas de input.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# O logid não está nos repos do Ubuntu; é compilado do fonte.
LOGIOPS_REPO="https://github.com/PixlOne/logiops.git"
LOGIOPS_DEPS=(cmake libevdev-dev libudev-dev libconfig++-dev build-essential pkg-config libglib2.0-dev)

build_logiops() {
  if command -v logid >/dev/null 2>&1; then
    skip "logid já instalado ($(command -v logid))"
    return 0
  fi

  log "compilando logiops (LogiOps) do fonte"
  run apt-get install -y "${LOGIOPS_DEPS[@]}"

  local tmp
  tmp="$(mktemp -d)"
  run git clone --depth 1 "$LOGIOPS_REPO" "$tmp/logiops"
  run cmake -S "$tmp/logiops" -B "$tmp/logiops/build" -DCMAKE_BUILD_TYPE=Release
  run cmake --build "$tmp/logiops/build" -j "$(nproc)"
  run cmake --install "$tmp/logiops/build"
  run rm -rf "$tmp"
  ok "logid compilado e instalado"
}

setup_logid() {
  install_file "etc/logid.cfg"
  install_file "etc/systemd/system/logid.service"
  run systemctl daemon-reload
  run systemctl enable --now logid
  run systemctl restart logid
  ok "logid ativo (MX Master 3S: botões laterais = volume)"
}

setup_extras() {
  # piper/ratbagd: GUI para configurar mouses gamer/Logitech suportados.
  local pkgs=(piper ratbagd)
  local missing=()
  for p in "${pkgs[@]}"; do has_pkg "$p" || missing+=("$p"); done
  if [ "${#missing[@]}" -gt 0 ]; then
    run apt-get install -y "${missing[@]}"
    ok "instalado: ${missing[*]}"
  else
    skip "piper/ratbagd já instalados"
  fi
}

main() {
  need_root
  build_logiops
  setup_logid
  setup_extras
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
