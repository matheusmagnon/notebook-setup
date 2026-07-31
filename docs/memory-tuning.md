# Tuning de memória

Contexto: **14 GiB de RAM**, uso pesado de Node/Chrome/Electron/Claude Code.
O sintoma que motivou tudo era travamentos/freezes quando a RAM acabava — o
notebook ficava minutos em thrashing de swap com a interface congelada.

Há três peças, cada uma cobrindo uma janela diferente do problema:

## 1. `vm.swappiness = 20` (sysctl)

Controla quão agressivamente o kernel move páginas anônimas (processos) pro
swap. O default do Ubuntu é 60: manda pra swap cedo, deixando RAM "livre" pra
cache de disco. Com 14 GiB e navegadores vorazes, isso significa que ao abrir
mais uma aba você tá pagando swap I/O em vez de usar RAM que estava lá.

- `0` ≈ quase nunca faz swap (RAM lotada → OOM killer rápido).
- `20` ← escolhido. Troca com relutância; mantém swap como rede de segurança,
  não como primeiro recurso.
- `60` (default) ← cedo demais pra esse perfil.

Também `vm.vfs_cache_pressure = 50`: recicla cache de dentry/inode (metadados
de arquivos) mais devagar, o que ajuda em fluxos com muitos arquivos pequenos
(`node_modules`, `git status`, tree-sitter).

## 2. `earlyoom` (daemon userspace)

O OOM killer do kernel só dispara quando a memória **acabou de fato** —
momento em que o sistema já está irrecoverável há um tempo. O earlyoom
monitora a RAM/swap e mata o processo mais faminto ANTES, restaurando a
máquina em ~1s em vez de minutos de congelamento.

Config atual (`/etc/default/earlyoom`):

```
-m 8 -s 5 -r 3600
--avoid '(systemd|gnome-shell|gdm3|Xorg|sshd|gnome-terminal-server|ptyxis)'
--prefer '(chrome|chromium|firefox|thunderbird|electron|code|cursor)'
```

- age quando RAM disponível < 8% **e** swap livre < 5%
- nunca escolhe a sessão gráfica / terminal como vítima
- prefere navegadores e Electron, que são quem mais incha

> `systemd-oomd` também fica ativo (vem no Ubuntu). Os dois coexistem sem
> conflito: o earlyoom é reativo por % disponível; o oomd atua por pressão
> (PSI). Pode deixar os dois.

## 3. Swap igualando prioridades

A máquina tinha duas áreas com prioridades diferentes:

| swap | tamanho | prioridade antiga |
|---|---|---|
| `/swap.img` | 4G | -2 (maior) |
| `/swapfile` | 16G | -3 (menor) |

Com prioridades diferentes, o kernel **enche a maior primeiro até o fim**
antes de tocar a outra. Resultado observado: `/swap.img` a 100% (4G/4G) e
`/swapfile` quase vazio. Com prioridades iguais o kernel intercala entre as
áreas, distribuindo a I/O — útil principalmente se algum dia estiverem em
discos diferentes.

O `10-memory.sh` iguala as prioridades no `/etc/fstab` (opção `pri=`). Como
há swap em uso, a mudança só vale após reboot — e o script avisa, sem fazer
`swapoff` (que forçaria os GB de volta pra RAM e travaria a máquina).

## Estado de referência (2026-07-30)

PSI de memória (.pressure) estava baixo após o tuning: `full avg60 ≈ 0.17`,
indicando pouca contenção real naquele momento.

## Sobre o `crashkernel`

O cmdline tem `crashkernel=2G-4G:320M,...` reservando RAM pro **kdump**
(captura de dump de kernel panic). Não é lixo: o `kdump-tools` está instalado
e funcional (`ready to kdump`). Mantido como opt-in — se quiser os ~512 MiB
de RAM de volta e não se importa com dumps de pânico:

```bash
sudo /usr/sbin/grub-editenv /boot/grub/grubenv unset kernel.sysroot  # não —
# na verdade, edite /etc/default/grub e remova a parte crashkernel= da GRUB_CMDLINE_LINUX_DEFAULT,
# depois: sudo update-grub
```

Não é alterado automaticamente porque mexe no boot.
