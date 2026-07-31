#!/usr/bin/env bash
# Módulo: pacotes — opcional. Restaura apps a partir das listas versionadas.
#
# É deliberadamente "best-effort": nunca aborta a instalação se um pacote
# faltar no repo. A ideia é que um notebook novo fique USÁVEL rápido, não
# que replique byte a byte o estado anterior.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --------------------------------------------------------------------- APT

install_apt_list() {
  local list="${REPO_ROOT}/linux/packages/apt.txt"
  [ -f "$list" ] || { skip "sem ${list}"; return 0; }

  log "verificando ${list} ($(wc -l < "$list") pacotes)"
  local missing=() p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    has_pkg "$p" || missing+=("$p")
  done < "$list"

  [ "${#missing[@]}" -gt 0 ] || { skip "nenhum pacote APT faltando"; return 0; }

  log "instalando ${#missing[@]} pacotes via APT (pode levar vários minutos)"
  log "pacotes: ${missing[*]}"

  # --no-install-recommends evita puxar dezenas de pacotes sugeridos que
  # inflam a lista e raramente são queridos. Remova se quiser os recommends.
  run apt-get install -y --no-install-recommends "${missing[@]}" 2>&1 \
    | grep -E '^(Inst|Conf|Err|E:)' || true

  # Relatar o que ainda não instalou (geralmente pacotes de repo de terceiro
  # cuja source não foi adicionada neste notebook).
  local still_missing=()
  for p in "${missing[@]}"; do has_pkg "$p" || still_missing+=("$p"); done
  if [ "${#still_missing[@]}" -gt 0 ]; then
    warn "não instalados (faltam repos de terceiros? ver linux/packages/third-party-repos.md):"
    for p in "${still_missing[@]}"; do warn "  - ${p}"; done
  fi
  ok "APT finalizado"
}

# -------------------------------------------------------------------- Snaps

install_snap_list() {
  local list="${REPO_ROOT}/linux/packages/snap.txt"
  [ -f "$list" ] || { skip "sem ${list}"; return 0; }
  command -v snap >/dev/null 2>&1 || { skip "snap não disponível"; return 0; }

  local installed p
  installed="$(snap list 2>/dev/null | awk 'NR>1 {print $1}')"
  local missing=()
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    grep -qx "$p" <<<"$installed" || missing+=("$p")
  done < "$list"

  [ "${#missing[@]}" -gt 0 ] || { skip "nenhum snap faltando"; return 0; }

  log "instalando snaps: ${missing[*]}"
  for p in "${missing[@]}"; do
    run snap install "$p" 2>&1 || warn "snap ${p} falhou"
  done
  ok "snaps finalizado"
}

# ------------------------------------------------------- Extensões GNOME

install_gnome_extensions() {
  local list="${REPO_ROOT}/linux/packages/gnome-extensions.txt"
  [ -f "$list" ] || { skip "sem ${list}"; return 0; }
  command -v gnome-extensions >/dev/null 2>&1 || { skip "gnome-extensions indisponível (sem GNOME?)"; return 0; }

  # Filtra só as que vêm de pacote APT (instaláveis via pacote, não via site).
  local pkg_for
  local installed
  installed="$(as_user gnome-extensions list 2>/dev/null)"

  while IFS= read -r ext; do
    [ -n "$ext" ] || continue
    grep -qx "$ext" <<<"$installed" \
      && { skip "extensão ${ext%%@*} já presente"; continue; }
    warn "extensão não instalada: ${ext} (instale via 'Extension Manager' ou apt)"
  done < "$list"
  ok "GNOME extensions verificadas"
}

main() {
  need_root
  run apt-get update
  install_apt_list
  install_snap_list
  install_gnome_extensions
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
