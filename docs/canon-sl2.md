# Canon SL2 / EOS 200D como webcam

A câmera não tem modo webcam nativo. O fluxo é: **gphoto2** captura o LiveView
por USB (PTP) e cospe MJPEG no stdout; **ffmpeg** reformatava e mandava pra um
dispositivo virtual. O que muda entre Linux e macOS é só o destino do ffmpeg.

## Linux

```
gphoto2 ──MJPEG──▶ ffmpeg ──▶ v4l2loopback (/dev/video10) ──▶ Meet/Zoom/OBS
```

O módulo `v4l2loopback` cria o dispositivo virtual. No Ubuntu 25.10+ ele **já
vem dentro do pacote do kernel** (`linux-modules-*`) — o `v4l2loopback-dkms` é
redundante e só gera o aviso "Differences between built and installed modules"
no `dkms status`. O `20-camera.sh` detecta a origem e instala o DKMS só quando
realmente necessário.

### Uso

```bash
canon-webcam              # melhor modo, com reconexão automática
canon-webcam --mode preview   # modo mais compatível
canon-webcam --check          # só diagnostica o ambiente
canon-webcam --stop           # libera a câmera e descarrega o módulo
```

Depois selecione **"Canon_SL2"** no seletor de câmera do Meet/Zoom.

### Pré-requisitos físicos

- Câmera **ligada**, bateria cheia (LiveView consome muito; recomendado
  alimentação por grip/AC se for sessão longa).
- Seletor no **modo de vídeo (movie)** — no modo foto o `viewfinder=1` pode
  não prender o LiveView.
- Cabo **USB de dados**. Cabos só de carga não enumeram a câmera; o gphoto2
  simplesmente não a encontra.

### Troubleshooting

| Sintoma | Causa provável | Solução |
|---|---|---|
| `câmera não detectada` | cabo de carga, ou câmera dormindo | trocar cabo; ligar e acordar a tela da câmera |
| `Permission denied` em `/dev/video10` | sem grupo `video` / regra udev | `sudo linux/install.sh --module 20-camera` e relogue |
| Stream cai depois de segundos | câmera adormece por economia | `canon-webcam` tem loop de reconexão; confira alimentação |
| imagem verde/distorcida | ffmpeg deduziu o formato errado | o script fixa `-f mjpeg`; não mexa |

Logs ficam em `~/.local/state/canon-webcam/`. Para debug pesado:

```bash
env LANG=C gphoto2 --debug \
  --debug-logfile=/tmp/gphoto-debug.txt --capture-movie
```

## macOS

```
gphoto2 ──MJPEG──▶ ffmpeg ──mpegts/udp──▶ OBS (Media Source) ──▶ Virtual Camera ──▶ Meet/Zoom
```

Sem `v4l2loopback` no macOS, o OBS faz o papel de "dispositivo virtual".
`canon-webcam` publica o stream em `udp://127.0.0.1:1234` (configurável via
`CANON_UDP_PORT`).

### Setup (uma vez)

1. `./macos/install.sh` instala gphoto2, ffmpeg e OBS.
2. Abra o OBS.
3. **Sources → + → Media Source**:
   - Desmarque *Local File*.
   - Em *Input*, cole: `udp://127.0.0.1:1234`
4. **Controls → Start Virtual Camera**.
5. `canon-webcam` — o OBS agora tem imagem.

> `Logi Options+` (cask) substitui o LogiOps do Linux para o MX Master 3S.

## Histórico — o que este script substitui

Este repo consolidou três scripts que faziam quase a mesma coisa com detalhes
diferentes (e um bug de permissão que mascarava a causa real):

| Script antigo | device | problema |
|---|---|---|
| `~/canon_webcam.sh` | video50 | sem `card_label`; ffmpeg sem `-f mjpeg` no input |
| `~/canon_webcam_optimized.sh` | video50 | perdeu o `card_label` do dispositivo |
| `~/Documents/preVideo2.sh` | video10 | usava `/dev/video10` antes do `udevadm settle` — pegava `root:root 0600` e o ffmpeg morria sem mensagem clara (registrado em `~/webcam-sl2-logs/debug-*.txt`) |

O novo `canon-webcam` padroniza device (`video10`), fixa o `card_label`, força
`-f mjpeg`, espera o udev antes de usar o device, tenta `movie`→`preview` e
tem loop de reconexão.
