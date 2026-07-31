# Estrutura do repo

```
notebook-setup/
├── bin/
│   └── canon-webcam          # webcam Canon (Linux + macOS), unifica 3 scripts
├── linux/
│   ├── install.sh            # ponto de entrada: sudo ./install.sh [--module M]
│   ├── lib.sh                # helpers: install_file, run, as_user, backup
│   ├── 10-memory.sh          # sysctl + earlyoom + swap
│   ├── 20-camera.sh          # v4l2loopback + udev + grupo video + canon-webcam
│   ├── 30-peripherals.sh     # logiops (MX Master 3S) + piper/ratbagd
│   ├── 40-packages.sh        # restauração opcional de apps (--packages)
│   ├── files/                # configs versionadas, espelham /etc
│   │   └── etc/
│   │       ├── sysctl.d/99-magno-tuning.conf
│   │       ├── udev/rules.d/99-v4l2loopback-perms.rules
│   │       ├── default/earlyoom
│   │       ├── systemd/system/logid.service
│   │       └── logid.cfg
│   └── packages/             # listas para recriar o ambiente de apps
│       ├── apt.txt
│       ├── snap.txt
│       ├── gnome-extensions.txt
│       └── third-party-repos.md
├── macos/
│   ├── install.sh            # Homebrew + Brewfile + canon-webcam
│   └── Brewfile
└── docs/
    ├── canon-sl2.md
    ├── memory-tuning.md
    └── structure.md          # este arquivo
```

## Princípios

- **Idempotente.** Rodar `install.sh` N vezes = mesmo resultado que rodar 1.
  Cada módulo checa o estado antes de agir e pula o que já está feito.
- **Backup antes de sobrescrever.** `install_file` guarda o original em
  `/var/backups/notebook-setup/` na primeira vez que mexe num arquivo.
- **Sem destruição.** Arquivos obsoletos são *aposentados* (movidos pro
  backup), nunca `rm`-ados diretamente.
- **Dry-run.** `sudo ./install.sh --dry-run` mostra todas as ações sem tocar
  no sistema — útil pra auditar antes de aplicar num notebook novo.
- **OS no script, não em repositórios separados.** `canon-webcam` detecta
  `uname -s` e usa o caminho certo (v4l2loopback no Linux, socket+OBS no
  macOS). Assim a interface de uso é a mesma nas duas plataformas.
