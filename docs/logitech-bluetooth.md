# Logitech no Bluetooth (MX Master 3S + K380)

Dois problemas resolvidos pelo módulo `30-peripherals` (`setup_bluetooth_tweaks`).

## 1. Rolagem lenta/atrasada do MX Master 3S no Bluetooth

**Sintoma:** no receptor Bolt a rodinha é ótima; no Bluetooth a rolagem no
navegador/GNOME fica lenta e "borrachuda".

**Causa:** no Bluetooth o driver do kernel `hid_logitech_hidpp` assume o mouse
e liga o *hi-res scroll*: cada dente da rodinha vira ~15 eventos de `8/120`.
A distância total está certa (10 dentes = 1200 unidades), mas o GNOME e os
navegadores tratam os microeventos como rolagem de precisão (tipo touchpad) e
a rolagem suave reinicia a cada evento. No receptor Bolt esse driver não
entra — o mouse é genérico e manda 1 evento de `120` por dente.

**Correção:** `/etc/modprobe.d/no-logitech-hidpp.conf` bloqueia o módulo.
Sem ele o BT se comporta igual ao receptor.

- Mantém: rolagem infinita (free-spin/SmartShift é mecânico), botões do
  `logid` (fala direto com o hidraw), bateria do mouse (BlueZ, GATT Battery
  Service → UPower).
- Perde: hi-res scroll e extras do kernel para Logitech.
- **Não funciona:** `hiresscroll { hires: false; }` no `logid.cfg` — o kernel
  continua escalando como hi-res e 10 dentes viram ~5,6.
- Reverter: apagar o arquivo e reiniciar.

Diagnóstico (gire 10 dentes no modo catraca; a soma deve dar ±1200):

```bash
sudo libinput debug-events | grep POINTER_SCROLL_WHEEL   # vert X/<v120>
```

## 2. Bateria do K380 no painel

**Sintoma:** o teclado some do "Bluetooth battery indicator" (ou mostra um
valor velho).

**Causa:** o K380 usa `hid-generic`, que só conhece a bateria quando o
teclado manda um relatório espontâneo (raro, ~quando muda de faixa). Sem ele
o UPower não lista o teclado — e a extensão só lê o UPower.

**Correção:** `/usr/local/bin/k380-battery`, rodado pelo timer de usuário
`k380-battery.timer` (30 s após o login e a cada 5 min):

1. lê a bateria via HID++ 2.0 (feature `0x1000` BatteryStatus) no hidraw e
   grava `~/.cache/k380-battery` (apaga se o teclado estiver desconectado);
2. injeta esse valor no `scripts/upower_devices.sh` da extensão — e
   **reaplica sozinho** se uma atualização da extensão sobrescrever o arquivo.

O acesso ao hidraw sem root vem de `70-k380-hidraw.rules` (`TAG+="uaccess"`).
Nas prefs da extensão, o registro "Keyboard K380 Keyboard" (MAC minúsculo)
precisa estar ativado; o do mouse é o de MAC **maiúsculo** (`DD:69:…`), pois
a bateria agora vem do BlueZ e não mais do driver hidpp.

```bash
systemctl --user status k380-battery.timer
/usr/local/bin/k380-battery && cat ~/.cache/k380-battery
```
