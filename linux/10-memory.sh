#!/usr/bin/env bash
# Módulo: memória — sysctl, earlyoom, swap, zram e limpeza de Chrome órfão.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SWAP_FILE="${SWAP_FILE:-/swapfile}"
SWAP_SIZE="${SWAP_SIZE:-16G}"
SWAP_PRI="${SWAP_PRI:-10}"

# ---------------------------------------------------------------------- sysctl

setup_sysctl() {
  log "sysctl: aplicando tuning de memória e inotify"
  install_file "etc/sysctl.d/99-magno-tuning.conf"

  # Consolidados no arquivo acima; deixar os antigos só duplica a configuração
  # e faz o valor efetivo depender da ordem alfabética de carregamento.
  retire_file /etc/sysctl.d/99-swappiness.conf
  retire_file /etc/sysctl.d/99-inotify.conf

  run sysctl --system >/dev/null
  ok "sysctl aplicado (swappiness=$(sysctl -n vm.swappiness 2>/dev/null))"
}

# -------------------------------------------------------------------- earlyoom

setup_earlyoom() {
  if ! has_pkg earlyoom; then
    log "earlyoom: instalando"
    run apt-get install -y earlyoom
  fi
  install_file "etc/default/earlyoom"
  run systemctl enable --now earlyoom
  run systemctl restart earlyoom
  ok "earlyoom ativo"
}

# ------------------------------------------------------------------------ swap

# Cria o swapfile só se ele não existir. Nunca redimensiona um existente:
# redimensionar exige swapoff, e swapoff com vários GB em uso força tudo de
# volta pra RAM — que é exatamente a situação que estamos tentando evitar.
ensure_swapfile() {
  if [ -f "$SWAP_FILE" ]; then
    skip "${SWAP_FILE} já existe ($(du -h "$SWAP_FILE" | cut -f1))"
    return 0
  fi

  local fstype
  fstype="$(findmnt -no FSTYPE -T "$(dirname "$SWAP_FILE")")"
  if [ "$fstype" = "btrfs" ]; then
    warn "raiz em btrfs: swapfile exige NOCOW + sem compressão. Pulando."
    warn "  crie manualmente: btrfs filesystem mkswapfile --size ${SWAP_SIZE} ${SWAP_FILE}"
    return 0
  fi

  log "criando ${SWAP_FILE} (${SWAP_SIZE})"
  run fallocate -l "$SWAP_SIZE" "$SWAP_FILE" \
    || run dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$(( ${SWAP_SIZE%G} * 1024 ))" status=progress
  run chmod 600 "$SWAP_FILE"
  run mkswap "$SWAP_FILE" >/dev/null
  grep -qs "^${SWAP_FILE}[[:space:]]" /etc/fstab \
    || run bash -c "printf '%s none swap sw,pri=%s 0 0\n' '$SWAP_FILE' '$SWAP_PRI' >> /etc/fstab"
  run swapon "$SWAP_FILE"
  ok "swapfile criado e ativo"
}

# Iguala a prioridade de todas as áreas de swap.
#
# Com prioridades diferentes o kernel enche a de maior prioridade até o fim
# antes de tocar na outra — foi o que aconteceu aqui: /swap.img (pri -2, 4G)
# ficou 100% cheio enquanto o /swapfile (pri -3, 16G) estava quase vazio.
# Com prioridades iguais ele intercala entre as áreas.
equalize_swap_priority() {
  local changed=0 tmp
  tmp="$(mktemp)"

  awk -v PRI="$SWAP_PRI" '
    /^[[:space:]]*#/ { print; next }
    NF >= 4 && $3 == "swap" {
      if ($4 ~ /(^|,)pri=/) { gsub(/pri=-?[0-9]+/, "pri=" PRI, $4) }
      else                  { $4 = $4 ",pri=" PRI }
      print; next
    }
    { print }
  ' /etc/fstab > "$tmp"

  if cmp -s "$tmp" /etc/fstab; then
    skip "prioridades de swap no fstab já estão iguais (pri=${SWAP_PRI})"
    rm -f "$tmp"
    return 0
  fi

  # Sanidade: não deixar o fstab menor do que era.
  [ "$(wc -l < "$tmp")" -ge "$(wc -l < /etc/fstab)" ] \
    || { rm -f "$tmp"; die "reescrita do fstab saiu malformada; abortando"; }

  run mkdir -p "$BACKUP_DIR"
  run cp -a /etc/fstab "${BACKUP_DIR}/fstab.$(date +%Y%m%d-%H%M%S)"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s   [dry-run] novo /etc/fstab:%s\n' "$c_dim" "$c_off"
    grep -E 'swap' "$tmp" | sed 's/^/      /'
  else
    cat "$tmp" > /etc/fstab
  fi
  rm -f "$tmp"
  changed=1

  ok "fstab atualizado com pri=${SWAP_PRI} em todas as áreas de swap"
  [ "$changed" = 1 ] && warn "a nova prioridade só vale após reiniciar.
    NÃO rode 'swapoff -a' para aplicar agora: há $(free -h | awk '/Swap/{print $3}') em uso
    e forçar isso de volta pra RAM pode travar a máquina."
}

# ------------------------------------------------------------------------ zram

# Swap comprimido em RAM, com prioridade acima do swap em disco (ver
# etc/systemd/zram-generator.conf). Ativar não mexe no swap em uso: só soma um
# dispositivo novo, então dá pra ligar sem reiniciar.
setup_zram() {
  # Config ANTES do pacote: o postinst do systemd-zram-generator já sobe o
  # zram0 — sem a config no lugar, ele nasce com o padrão (4G, lzo-rle).
  install_file "etc/systemd/zram-generator.conf"
  if ! has_pkg systemd-zram-generator; then
    log "zram: instalando systemd-zram-generator"
    run apt-get install -y systemd-zram-generator
  fi
  run systemctl daemon-reload

  local algo usado
  algo="$(zramctl --output ALGORITHM --noheadings /dev/zram0 2>/dev/null | tr -d ' ' || true)"
  if [ -z "$algo" ]; then
    run systemctl start systemd-zram-setup@zram0.service
    ok "zram0 ativo"
  elif [ "$algo" = "zstd" ]; then
    skip "zram0 já ativo ($(zramctl --output DISKSIZE --noheadings /dev/zram0 | tr -d ' '), zstd)"
  else
    # Recriar = swapoff do zram0, que devolve o conteúdo pra RAM. Só com
    # pouco dado dentro; com muito, fica pro próximo boot.
    usado="$(zramctl --output DATA --bytes --noheadings /dev/zram0 | tr -d ' ')"
    if [ "${usado:-0}" -lt $((1024 * 1024 * 1024)) ]; then
      # restart direto falha com EBUSY: o reset do dispositivo precisa do
      # swap já desligado. Ordem: desliga o swap, reseta, recria, religa.
      run systemctl stop dev-zram0.swap
      run sh -c 'echo 1 > /sys/block/zram0/reset'
      run systemctl start systemd-zram-setup@zram0.service
      run systemctl start dev-zram0.swap
      ok "zram0 recriado com a config do repo (estava em ${algo})"
    else
      warn "zram0 está em ${algo} com $((usado / 1024 / 1024)) MiB em uso — a config nova vale no próximo boot"
    fi
  fi
}

# -------------------------------------------------- Chrome headless órfão

# Chrome de automação (Puppeteer/Playwright, chrome-devtools-mcp) que perdeu o
# dono e ficou pendurado — ver usr/local/bin/mata-chrome-orfao.
setup_chrome_reaper() {
  install_file "usr/local/bin/mata-chrome-orfao" 755
  install_file "etc/systemd/system/mata-chrome-orfao.service"
  install_file "etc/systemd/system/mata-chrome-orfao.timer"
  run systemctl daemon-reload
  run systemctl enable --now mata-chrome-orfao.timer
  # Primeira passada agora, sem esperar o timer.
  run systemctl start mata-chrome-orfao.service
  ok "mata-chrome-orfao: timer ativo (a cada 30 min)"
}

main() {
  need_root
  setup_sysctl
  setup_earlyoom
  ensure_swapfile
  equalize_swap_priority
  setup_zram
  setup_chrome_reaper
}

[ "${BASH_SOURCE[0]}" = "${0}" ] && main "$@"
