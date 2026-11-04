#!/usr/bin/env bash
# Módulo: periféricos — mouse Logitech (LogiOps), ajustes de Bluetooth
# (scroll do MX, bateria do K380 — ver docs/logitech-bluetooth.md) e input.
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
  ok "logid ativo (MX Master 3S: botões laterais = volume, gesto = Super)"
}

setup_bluetooth_tweaks() {
  # MX Master 3S via Bluetooth: o driver hid_logitech_hidpp liga hi-res scroll
  # (15 eventos de 8/120 por dente) e a rolagem fica lenta/atrasada no
  # GNOME/navegador. Bloqueado, o BT se comporta igual ao receptor Bolt.
  # Botões continuam via logid (hidraw); bateria via BlueZ (GATT).
  install_file "etc/modprobe.d/no-logitech-hidpp.conf"
  if lsmod | grep -q '^hid_logitech_hidpp'; then
    warn "hid_logitech_hidpp ainda carregado — reconecte o mouse ou reinicie para valer"
  fi

  # K380: bateria só aparece no painel via k380-battery (HID++ direto no hidraw).
  install_file "etc/udev/rules.d/70-k380-hidraw.rules"
  run udevadm control --reload
  run udevadm trigger --subsystem-match=hidraw
  install_file "usr/local/bin/k380-battery" 755
  install_file "etc/systemd/user/k380-battery.service"
  install_file "etc/systemd/user/k380-battery.timer"
  run systemctl --global enable k380-battery.timer

  local uid bus
  uid="$(id -u "$TARGET_USER")"
  bus="unix:path=/run/user/${uid}/bus"
  if [ -S "/run/user/${uid}/bus" ]; then
    run sudo -u "$TARGET_USER" env "DBUS_SESSION_BUS_ADDRESS=$bus" \
      systemctl --user daemon-reload
    run sudo -u "$TARGET_USER" env "DBUS_SESSION_BUS_ADDRESS=$bus" \
      systemctl --user start k380-battery.timer k380-battery.service
  fi
  ok "Bluetooth: scroll do MX sem hi-res; bateria do K380 no painel"
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
  setup_bluetooth_tweaks
  setup_extras
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
