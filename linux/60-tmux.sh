#!/usr/bin/env bash
# Módulo: tmux — resiliência de sessão de terminal. A GUI reinicia ~1×/semana
# (GNOME Shell) e o Ghostty é instância única: sem isso, tudo que rodava nas
# abas morre junto. Com o tmux, processos seguem detachados — reabre o
# terminal, `ta`, e segue de onde estava. Config em files/home (não em /etc).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_tmux() {
  if ! has_pkg tmux || ! has_pkg wl-clipboard; then
    log "tmux: instalando pacotes (wl-clipboard p/ copy no Wayland)"
    run apt-get install -y tmux wl-clipboard
  fi

  install_file "home/${TARGET_USER}/.tmux.conf"
  run chown "${TARGET_USER}:" "/home/${TARGET_USER}/.tmux.conf"

  # alias `ta` no .bashrc do usuário — attach-ou-cria a sessão main,
  # idempotente (não duplica a linha em re-runs).
  local bashrc="/home/${TARGET_USER}/.bashrc"
  if as_user grep -qs "alias ta=" "$bashrc"; then
    skip "alias ta já existe no .bashrc"
  else
    as_user bash -c "printf '\n# tmux: sempre cai na sessão principal (attach-ou-cria)\nalias ta=\"tmux new -A -s main\"\n' >> '${bashrc}'"
    ok "alias ta adicionado ao .bashrc"
  fi

  ok "tmux pronto — 'ta' entra na sessão main (Ctrl+B d sai sem matar nada)"
}

main() {
  need_root
  setup_tmux
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
