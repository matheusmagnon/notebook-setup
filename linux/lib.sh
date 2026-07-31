#!/usr/bin/env bash
# Helpers compartilhados pelos módulos de instalação. Sourced, não executado.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES="${REPO_ROOT}/linux/files"
BACKUP_DIR="/var/backups/notebook-setup"

DRY_RUN="${DRY_RUN:-0}"

# Quem é o usuário humano, mesmo rodando sob sudo.
TARGET_USER="${SUDO_USER:-${USER}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"

c_blue=$'\033[1;34m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'
c_green=$'\033[1;32m'; c_dim=$'\033[2m'; c_off=$'\033[0m'

log()  { printf '%s::%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '%s ok%s %s\n' "$c_green" "$c_off" "$*"; }
skip() { printf '%s  -%s %s\n' "$c_dim" "$c_off" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
die()  { printf '%sxx%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s   [dry-run] %s%s\n' "$c_dim" "$*" "$c_off"
  else
    "$@"
  fi
}

need_root() {
  [ "$(id -u)" -eq 0 ] || die "este script precisa de root. Rode: sudo $0"
}

# Copia um arquivo do repo para o sistema, guardando o original uma vez.
# uso: install_file <caminho relativo a linux/files> [modo]
install_file() {
  local rel="$1" mode="${2:-644}"
  local src="${FILES}/${rel}" dst="/${rel}"

  [ -f "$src" ] || die "arquivo do repo não encontrado: $src"

  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    skip "${dst} já está atualizado"
    return 0
  fi

  if [ -f "$dst" ]; then
    local bak="${BACKUP_DIR}/$(echo "$rel" | tr / _).$(date +%Y%m%d-%H%M%S)"
    run mkdir -p "$BACKUP_DIR"
    run cp -a "$dst" "$bak"
    log "backup do original em ${bak}"
  fi

  run install -D -m "$mode" "$src" "$dst"
  ok "instalado ${dst}"
}

# Move um arquivo obsoleto para o backup em vez de apagar.
retire_file() {
  local path="$1"
  [ -e "$path" ] || { skip "${path} não existe (nada a aposentar)"; return 0; }
  run mkdir -p "$BACKUP_DIR"
  run mv "$path" "${BACKUP_DIR}/$(basename "$path").retired.$(date +%Y%m%d-%H%M%S)"
  ok "aposentado ${path} (movido para ${BACKUP_DIR})"
}

as_user() {
  if [ "$(id -u)" -eq 0 ] && [ "$TARGET_USER" != "root" ]; then
    run sudo -u "$TARGET_USER" "$@"
  else
    run "$@"
  fi
}

has_pkg() { dpkg -s "$1" >/dev/null 2>&1; }
