# Tuning de memória

Contexto: **14 GiB de RAM**, uso pesado de Node/Chrome/Electron/Claude Code.
O sintoma que motivou tudo era travamentos/freezes quando a RAM acabava — o
notebook ficava minutos em thrashing de swap com a interface congelada.

Há seis peças, cada uma cobrindo uma janela diferente do problema:

## 1. sysctls de swap comprimido (2026-11-18)

Revisados no deep research de nov/2026 (93 fontes: kernel docs, Arch Wiki,
Phoronix, fóruns Fedora/openSUSE). A premissa antiga — trocar relutante — era
calibrada pra swap **em disco**; com swap **comprimido em RAM** (zswap),
"trocar" uma página fria é quase grátis e *libera* RAM pra page cache (o
código dos apps). A doc do kernel endossa swappiness **> 100** quando o swap
é mais rápido que o filesystem:

- `vm.swappiness = 180` — consenso Arch/Pop!_OS/Fedora pra swap comprimido;
  troca cedo e barato, mantém o quente na RAM. (Era 20.)
- `vm.page-cluster = 0` — swap comprimido lê aleatório; cluster 3 (8 páginas
  por leitura) era pra disco mecânico. Medido: 2,03M IOPS vs 366k.
- `vm.watermark_scale_factor = 125` — acorda o kswapd com ~180 MiB de folga
  em vez de ~14 MiB; menos direct reclaim (o micro-freeze). (Era 10.)
- `vm.watermark_boost_factor = 0` — desliga o reclaim pânico pós-pico, que
  só gerava swap desnecessário depois de picos momentâneos.
- `vm.vfs_cache_pressure = 75` — meio-termo do tuning Fedora. (Era 50.)

`inotify` alto p/ dev segue como está (watchers de vite/tsc/jest).

## 2. `earlyoom` (daemon userspace)

O OOM killer do kernel só dispara quando a memória **acabou de fato** —
momento em que o sistema já está irrecoverável há um tempo. O earlyoom
monitora a RAM/swap e mata o processo mais faminto ANTES, restaurando a
máquina em ~1s em vez de minutos de congelamento.

Config atual (`/etc/default/earlyoom`):

```
-m 8 -s 5 -r 3600
--ignore '(ghostty|claude)'
--avoid  '(systemd|gnome-shell|gdm3|Xorg|sshd|gnome-terminal-server|ptyxis)'
--prefer '(chrome|chromium|chrome-headless|firefox|Isolated.Web.Co|Web.Content|thunderbird|electron|code|cursor)'
```

- age quando RAM disponível < 8% **e** swap livre < 5%
- `--ignore` = **nunca** escolhe (sai da lista de candidatos): o `ghostty`
  (instância única — matá-lo derruba todas as abas) e cada sessão do Claude
  Code (`claude`). Casa pelo nome exato do processo: o que as sessões
  disparam (`node`, `next dev`, Chrome) continua matável — se um teste
  estourar a memória, morre o teste, não a sessão.
- `--avoid` = só em último caso (perde pontos, mas ainda pode morrer):
  sessão gráfica e terminais padrão
- `--prefer` = vítimas preferidas: navegadores e Electron. As **abas do
  Firefox** se chamam `Isolated Web Co` / `Web Content` (não `firefox`) — sem
  esses nomes a preferência só valia pro processo principal. O `.` casa com o
  espaço: o systemd divide `$EARLYOOM_ARGS` em argumentos e um espaço literal
  dentro do regex não é seguro.

Limite assumido: se o processo que vaza for a **própria** sessão do Claude,
nada automático a mata — o earlyoom sacrifica o resto e, no extremo, decide o
OOM killer do kernel. (Não usamos `oom_score_adj=-1000` no ghostty: o valor é
herdado por tudo que nasce no terminal e deixaria `node`/Chrome imortais.)

> `systemd-oomd` vem ativo no Ubuntu, mas desde 2026-11-18 é **desligado e
> masked**: ele mata o *cgroup* inteiro — na sessão GNOME isso derruba a
> sessão toda (systemd#35270, relatos em Ubuntu/Fedora) — e o preset do
> release upgrade o reativa (aconteceu no upgrade pra 26.04); só o `mask`
> sobrevive. O earlyoom fica sozinho de guarda: dispara por % disponível e
> mata o processo, não o cgroup.

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

> Em 2026-11-18 o `/swap.img` foi removido de vez (fstab comentado + arquivo
> apagado): com zswap na frente, um swapfile de 16 GiB é mais que suficiente
> pra 14 GiB de RAM — e sobraram 4 GiB de disco.

## 4. zswap (cache comprimido na frente do swapfile)

Desde 2026-11-18, no lugar do zram. O zram funcionava (compressão real de
3,6× com zstd), mas seu modo de falha era estrutural: **encheu, parou** — a
partir daí o kernel ia direto pro disco sem compressão nenhuma, e o writeback
do zram não é integrado ao gerenciador de memória (exigiria dispositivo
dedicado + timers manuais). Era exatamente o estado observado no diagnóstico:
zram 100% cheio + 9,4 GiB no swapfile.

O zswap é um **pool comprimido na RAM que fica na frente do swapfile**: a
página fria entra no pool (zstd, até 25% da RAM ≈ 3,5 GiB que seguram ~12 GiB
a 3,5×) e, quando o pool enche, o kernel evicta pro disco as páginas *mais
frias de todas*, automaticamente — compressão sempre ativa, transbordo
ordenado. Config na cmdline do GRUB: `zswap.enabled=1 zswap.compressor=zstd
zswap.zpool=zsmalloc zswap.max_pool_percent=25`.

A regra de decisão (NixOS wiki, engenheiro da Canonical, Chris Down):
**sem swap em disco → zram; com swapfile → zswap; nunca os dois juntos** —
são políticas independentes competindo pelo mesmo trabalho. O `10-memory.sh`
remove o `systemd-zram-generator` se a máquina ainda o tiver.

Por que não dobrar o swap em disco (proposta considerada em 2026-10-09): o
swap estava 19/20 GiB cheio de **lixo vazado** (ver item 5), não de trabalho
ativo. Com 40 GiB ele guardaria o dobro de lixo — e o earlyoom (`-s 5`) só
reagiria com 2 GiB livres em vez de 1 GiB, ou seja, travamento mais longo
antes de agir.

## 5. Chrome headless órfão (`mata-chrome-orfao`)

Diagnóstico de 2026-10-09: **26 árvores de Chrome órfãs** (275 processos,
~2,3 GiB de RAM + ~5 GiB de swap, a mais velha com 8 dias). São Chromes de
automação — `chrome-devtools-mcp` de cada sessão do Claude Code, Puppeteer do
backend gerando PDF, Playwright — cujo dono morreu sem fechar o browser.

`/usr/local/bin/mata-chrome-orfao` roda a cada 30 min (`mata-chrome-orfao.timer`)
e encerra só o que cumpre **os três** critérios: raiz `chrome`/`chrome-headless`,
pai = systemd (dono morto) e perfil temporário de automação em `/tmp`
(`puppeteer_dev_chrome_profile-*` / `playwright_chromiumdev_profile-*`), órfão
há mais de 10 min. O Chrome de uso pessoal (perfil em `~/.config`) nunca casa.
Teste manual: `mata-chrome-orfao --dry-run`.

## 6. MGLRU `min_ttl_ms=1000` (anti-thrashing)

O Multi-Gen LRU (novo algoritmo de reposição de páginas do kernel) já vem
ativo (`lru_gen/enabled=0x0007`). O que faltava era o freio: `min_ttl_ms`
garante que uma página usada há menos de 1 s não seja sacrificada sob
pressão, cortando o loop "swapa e remosstra em seguida" — o congelamento
clássico. A doc do kernel: 1000 ms "elimina janks intoleráveis". Aplicado
pela unit `mglru-min-ttl.service` (sem ela, volta a 0 a cada boot).

## Estado de referência (2026-11-19)

Após o upgrade pra 26.04.1 LTS (kernel 7.0.0-43): zswap ativo, swap único
de 16 GiB a **0 B** depois de 9h ligado, ~11 GiB disponíveis, disco a 61%
(limpeza de 136 GiB no dia anterior). OOM: earlyoom sozinho (oomd masked).

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
