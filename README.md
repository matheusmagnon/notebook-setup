# notebook-setup

Configurações pessoais de um notebook de dev — prontas para clonar e rodar
quando a máquina mudar. Hoje roda em **Ubuntu 25.10**; projetado para também
cobrir **macOS** num futuro próximo.

Tudo é idempotente: pode rodar quantas vezes quiser.

## O que isto configura

1. **Memória** — `swappiness=20`, `vfs_cache_pressure=50`, `inotify` alto p/
   dev, e o `earlyoom` (mata o processo faminto antes do sistema travar).
   Resolve o sintoma de freeze com 14 GiB de RAM sob Electron/Chrome.
2. **Câmera Canon SL2/EOS 200D como webcam** — gphoto2 + v4l2loopback (Linux)
   ou gphoto2 + OBS Virtual Camera (macOS). Um único comando `canon-webcam`.
3. **Periféricos** — LogiOps p/ o MX Master 3S (botões laterais = volume),
   piper/ratbagd.
4. **Doca em duas telas** — patch na Ubuntu Dock para ela aparecer num
   *subconjunto* de monitores (a interface só oferece "um" ou "todos"). A lista
   fica em `~/.config/ubuntu-dock-monitors.conf`.
5. *(opcional)* **Apps** — restaura a lista de pacotes APT, snaps e extensões
   GNOME a partir de listas versionadas.

## Começando (Ubuntu)

```bash
git clone git@github.com:matheusmagnon/notebook-setup.git ~/repos/personal/notebook-setup
cd ~/repos/personal/notebook-setup

# ver o que faria, sem tocar em nada:
sudo ./linux/install.sh --dry-run

# aplicar a configuração de base:
sudo ./linux/install.sh

# (opcional) restaurar os apps também — demorado:
sudo ./linux/install.sh --packages
```

Rodar módulos individuais:

```bash
sudo ./linux/install.sh --module 10-memory,20-camera
```

## Começando (macOS)

```bash
./macos/install.sh          # instala Homebrew, Brewfile e canon-webcam
./macos/install.sh --check  # só diagnostica
```

## Câmera Canon (uso diário)

```bash
canon-webcam              # transmite, com reconexão automática
canon-webcam --check      # diagnóstico do ambiente
canon-webcam --mode preview   # modo mais compatível
canon-webcam --stop       # libera a câmera e descarrega o módulo
```

Detalhes, troubleshooting e o porquê de cada decisão em
[`docs/`](docs/) — em especial [`canon-sl2.md`](docs/canon-sl2.md),
[`memory-tuning.md`](docs/memory-tuning.md) e
[`dock-multi-monitor.md`](docs/dock-multi-monitor.md).

## Variáveis de ambiente (opcional)

| Variável | Default | Para quê |
|---|---|---|
| `CANON_DEVICE_NR` | `10` | número do `/dev/videoN` no Linux |
| `CANON_LABEL` | `Canon_SL2` | nome que aparece no seletor |
| `CANON_FPS` | `25` | framerate do stream |
| `CANON_UDP_PORT` | `1234` | socket OBS (macOS) |
| `SWAP_FILE` / `SWAP_SIZE` | `/swapfile` / `16G` | swapfile a criar |
| `DRY_RUN` | `0` | mostra ações sem executar |

## Estrutura

Veja [`docs/structure.md`](docs/structure.md). Em resumo: configs versionadas
em `linux/files/` espelham `/etc`; scripts de módulo em `linux/NN-*.sh`
aplicam-nas via helpers de `linux/lib.sh`.
