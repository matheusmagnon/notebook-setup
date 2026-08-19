#!/usr/bin/env bash
# Módulo: Ubuntu Dock em um subconjunto de monitores.
#
# A extensão ubuntu-dock só oferece "um monitor" ou "todos". Este módulo
# instala um patch que, com multi-monitor ligado, mostra a doca apenas nos
# conectores listados em ~/.config/ubuntu-dock-monitors.conf.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DOCK_SCHEMA="org.gnome.shell.extensions.dash-to-dock"
DOCK_CONF="${TARGET_HOME}/.config/ubuntu-dock-monitors.conf"

# gsettings precisa do bus da sessão do usuário quando chamado sob root.
user_gsettings() {
  local uid bus
  uid="$(id -u "$TARGET_USER")"
  bus="unix:path=/run/user/${uid}/bus"
  if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
    run sudo -u "$TARGET_USER" env "DBUS_SESSION_BUS_ADDRESS=$bus" gsettings "$@"
  else
    run gsettings "$@"
  fi
}

install_patch() {
  install_file "usr/local/bin/ubuntu-dock-monitors-patch" 755
  install_file "etc/apt/apt.conf.d/99-ubuntu-dock-monitors-patch"
  run /usr/local/bin/ubuntu-dock-monitors-patch
}

seed_conf() {
  if [ -f "$DOCK_CONF" ]; then
    skip "${DOCK_CONF} já existe"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s   [dry-run] cria %s%s\n' "$c_dim" "$DOCK_CONF" "$c_off"
    return 0
  fi
  cat > "$DOCK_CONF" <<'CONF'
# Monitores (conectores) onde a Ubuntu Dock deve aparecer.
# Um por linha; '#' comenta. Vale só com multi-monitor ligado:
#   gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true
# Arquivo ausente/vazio = comportamento padrão (todos os monitores).
#
# Nomes dos conectores:
#   gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
#     --object-path /org/gnome/Mutter/DisplayConfig \
#     --method org.gnome.Mutter.DisplayConfig.GetCurrentState
#
# magno-note: eDP-1 = tela embutida | DP-1 = LG 34" | DP-3 = GWD 16"
eDP-1
CONF
  chown "$TARGET_USER": "$DOCK_CONF"
  ok "criado ${DOCK_CONF} (edite a lista de monitores)"
}

enable_multimonitor() {
  user_gsettings set "$DOCK_SCHEMA" multi-monitor true
  ok "multi-monitor ligado (a lista do .conf faz o recorte)"
}

main() {
  need_root
  install_patch
  seed_conf
  enable_multimonitor
  warn "faça logout/login para o GNOME recarregar a extensão"
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
