#!/usr/bin/env bash
# Módulo: câmera — Canon DSLR como webcam via gphoto2 + v4l2loopback.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CAMERA_PKGS=(gphoto2 ffmpeg v4l2loopback-utils)

# ------------------------------------------------------------------- pacotes

setup_packages() {
  local missing=()
  for p in "${CAMERA_PKGS[@]}"; do has_pkg "$p" || missing+=("$p"); done

  # O v4l2loopback pode vir de dois lugares:
  #   1) o próprio pacote do kernel (Ubuntu >= 25.10 embarca o módulo), ou
  #   2) o pacote v4l2loopback-dkms, que recompila a cada kernel novo.
  # Instalar o DKMS quando o kernel já traz o módulo é redundante: o DKMS
  # compila, não sobrescreve o do kernel, e o `dkms status` passa a reclamar
  # "Differences between built and installed modules" pra sempre.
  if modinfo v4l2loopback >/dev/null 2>&1; then
    local provider
    provider="$(dpkg -S "$(modinfo -n v4l2loopback)" 2>/dev/null | cut -d: -f1 || true)"
    if [ -n "$provider" ] && [[ "$provider" == linux-modules-* ]]; then
      ok "v4l2loopback já vem do kernel (${provider}) — DKMS não é necessário"
    else
      ok "v4l2loopback presente (${provider:-origem desconhecida})"
    fi
  else
    log "v4l2loopback ausente: instalando via DKMS"
    missing+=(v4l2loopback-dkms)
  fi

  if [ "${#missing[@]}" -gt 0 ]; then
    log "instalando: ${missing[*]}"
    run apt-get install -y "${missing[@]}"
  else
    skip "pacotes de câmera já instalados"
  fi
}

# --------------------------------------------------------------------- udev

setup_udev() {
  install_file "etc/udev/rules.d/99-v4l2loopback-perms.rules"
  run udevadm control --reload-rules
  run udevadm trigger --subsystem-match=video4linux
  ok "regra udev aplicada"
}

# ------------------------------------------------------------- grupo 'video'

setup_video_group() {
  if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx video; then
    skip "${TARGET_USER} já está no grupo video"
    return 0
  fi
  run usermod -aG video "$TARGET_USER"
  ok "${TARGET_USER} adicionado ao grupo video"
  warn "faça logout/login (ou reinicie) para o grupo valer na sessão gráfica"
}

# ------------------------------------------------------------------- script

install_script() {
  local bindir="${TARGET_HOME}/.local/bin"
  as_user mkdir -p "$bindir"
  run install -m755 -o "$TARGET_USER" -g "$TARGET_USER" \
    "${REPO_ROOT}/bin/canon-webcam" "${bindir}/canon-webcam"
  ok "canon-webcam instalado em ${bindir}/canon-webcam"

  case ":${PATH}:" in
    *":${bindir}:"*) ;;
    *) warn "${bindir} não está no PATH desta sessão (normalmente o ~/.profile do Ubuntu já adiciona)" ;;
  esac
}

main() {
  need_root
  setup_packages
  setup_udev
  setup_video_group
  install_script
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
