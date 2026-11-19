#!/usr/bin/env bash
# Módulo: docker — o Docker Desktop crasha no boot ("qemu: process
# terminated unexpectedly: signal: aborted") quando o Ubuntu restringe user
# namespaces não privilegiados via AppArmor. Fix: sysctl dedicado (ver
# files/etc/sysctl.d/99-docker-desktop-userns.conf).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_docker() {
  if has_pkg docker-desktop; then
    install_file "etc/sysctl.d/99-docker-desktop-userns.conf"
    run sysctl --system >/dev/null
    ok "userns irrestrito p/ o Docker Desktop (qemu deixa de abortar)"
  else
    skip "docker-desktop não instalado"
  fi
}

main() {
  need_root
  setup_docker
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
