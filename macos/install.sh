#!/usr/bin/env bash
#
# install.sh — configura um notebook macOS (Apple Silicon ou Intel).
#
# O macOS NÃO tem v4l2loopback, então a câmera Canon funciona por um caminho
# diferente: gphoto2 -> ffmpeg -> socket UDP -> OBS -> Virtual Camera.
# O script `bin/canon-webcam` detecta o SO e usa o caminho certo.
#
# Uso:
#   ./install.sh            # instala Homebrew, Brewfile e canon-webcam
#   ./install.sh --check    # só diagnostica
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
REPO_ROOT="$(pwd)"

c_blue=$'\033[1;34m'; c_yellow=$'\033[1;33m'; c_red=$'\033[1;31m'
c_green=$'\033[1;32m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
log()  { printf '%s::%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '%s ok%s %s\n' "$c_green" "$c_off" "$*"; }
warn() { printf '%s!!%s %s\n' "$c_yellow" "$c_off" "$*" >&2; }
die()  { printf '%sxx%s %s\n' "$c_red" "$c_off" "$*" >&2; exit 1; }

ACTION="install"
[ "${1:-}" = "--check" ] && ACTION="check"

[ "$(uname -s)" = "Darwin" ] || die "este script é para macOS."

# --------------------------------------------------------------- Homebrew
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    skip_msg "Homebrew já instalado ($(command -v brew))"
    return 0
  fi
  log "Instalando Homebrew (pedirá a senha do sudo do macOS)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Apple Silicon instala em /opt/homebrew; precisa estar no PATH.
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  ok "Homebrew instalado"
}
skip_msg() { printf '%s  -%s %s\n' "$c_dim" "$c_off" "$*"; }

# --------------------------------------------------------------- Brewfile
run_brewfile() {
  command -v brew >/dev/null 2>&1 || die "brew não encontrado no PATH.
    Se acabou de instalar, abra um terminal novo ou:
      eval \"\$(/opt/homebrew/bin/brew shellenv)\""
  log "Instalando pacotes do Brewfile..."
  brew bundle --file="${REPO_ROOT}/macos/Brewfile"
  ok "Brewfile aplicado"
}

# ------------------------------------------------------------- canon-webcam
install_script() {
  local bindir="${HOME}/.local/bin"
  mkdir -p "$bindir"
  install -m755 "${REPO_ROOT}/bin/canon-webcam" "${bindir}/canon-webcam"

  case ":${PATH}:" in
    *":${bindir}:"*) ;;
    *) warn "${bindir} não está no PATH. Adicione ao ~/.zshrc:
       export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
  ok "canon-webcam instalado em ${bindir}"
}

# --------------------------------------------------------------- macOS defaults
# Pequenos defaults que reproduzem hábitos do setup Linux. Comentados por
# padrão — mexer em defaults via script é invasivo; descomente com critério.
setup_defaults() {
  : # exemplo (descomente se quiser):
  # defaults write com.apple.dock autohide -bool true
  # defaults write com.apple.dock orientation -string 'left'
  # killall Dock
}

do_check() {
  log "Sistema: $(sw_vers -productVersion) ($(uname -m))"
  command -v brew >/dev/null 2>&1 && ok "brew: $(command -v brew)" || warn "brew ausente"
  command -v gphoto2 >/dev/null 2>&1 && ok "gphoto2 ok" || warn "gphoto2 ausente (brew install gphoto2)"
  command -v ffmpeg >/dev/null 2>&1 && ok "ffmpeg ok" || warn "ffmpeg ausente"
  [ -d /Applications/OBS.app ] && ok "OBS instalado" || warn "OBS ausente (brew install --cask obs)"
  command -v canon-webcam >/dev/null 2>&1 && ok "canon-webcam no PATH" || warn "canon-webcam ausente"
}

case "$ACTION" in
  check)   do_check ;;
  install) ensure_brew; run_brewfile; install_script; setup_defaults; do_check ;;
esac
