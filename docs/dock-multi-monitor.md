# Ubuntu Dock em duas telas (nem uma, nem todas)

## O problema

A doca do Ubuntu (`ubuntu-dock@ubuntu.com`, um fork do Dash to Dock) expõe em
**Configurações → Ubuntu Desktop → Doca → Mostrar no** apenas duas famílias de
escolha: **um** monitor específico ou **todos os monitores**. Não existe opção
para "estas duas telas". No dconf isso é um booleano:

```
org.gnome.shell.extensions.dash-to-dock multi-monitor            false
org.gnome.shell.extensions.dash-to-dock preferred-monitor-by-connector 'DP-3'
```

Em `docking.js`, `DockManager._createDocks()` cria a doca principal no monitor
preferido e, se `multi-monitor` estiver ligado, faz um `for` em **todos** os
monitores criando uma doca em cada. Não há filtro no meio.

## Por que o patch vai em /usr/share (e não em ~/.local/share)

Normalmente uma extensão em `~/.local/share/gnome-shell/extensions/<uuid>`
tem precedência sobre a versão do sistema. Mas `ubuntu-dock@ubuntu.com` está
listada em `/usr/share/gnome-shell/modes/ubuntu.json` → é *mode extension*, e o
GNOME do Ubuntu tem um bloqueio explícito (`ui/extensionSystem.js`,
`_loadExtensions`):

```js
if (Desktop.is('ubuntu') && this.isModeExtension(uuid) && type === ExtensionType.PER_USER) {
    log(`Found user extension ${uuid}, but not loading from ${dir.get_path()} directory as part of session mode.`);
    return null;
}
```

Ou seja: cópia no home é ignorada. Sobram duas saídas — clonar a extensão com
outro UUID (perde o painel de Configurações) ou patchar o arquivo do sistema.
Escolhemos a segunda, com reaplicação automática via hook do apt.

## O que o patch faz

`/usr/local/bin/ubuntu-dock-monitors-patch` insere em `docking.js`:

1. `DockManager._getAllowedMonitors()` — lê `~/.config/ubuntu-dock-monitors.conf`
   (um conector por linha) e traduz para índices via
   `MonitorManager.get_monitor_for_connector()`. Sem arquivo, sem linhas válidas
   ou com `multi-monitor` desligado, devolve `null` = comportamento original.
2. No `_createDocks()`: garante que a doca principal caia num monitor permitido
   e faz o loop multi-monitor pular os monitores fora da lista.

Propriedades:

- **Idempotente** — reconhece o marcador `monitors-whitelist patch` e não
  aplica duas vezes.
- **Backup** — o original vai para `/var/lib/ubuntu-dock-monitors/docking.js.dist`.
- **Falha segura** — se a extensão mudar de versão e as âncoras não casarem
  exatamente uma vez, o script aborta sem tocar no arquivo.
- **Sobrevive a upgrade** — `/etc/apt/apt.conf.d/99-ubuntu-dock-monitors-patch`
  reaplica no `DPkg::Post-Invoke` depois que o apt atualiza o pacote
  `gnome-shell-extension-ubuntu-dock`.

## Uso

```bash
# lista de monitores (conectores), um por linha
$EDITOR ~/.config/ubuntu-dock-monitors.conf

# nomes dos conectores conectados agora
gdbus call --session --dest org.gnome.Mutter.DisplayConfig \
  --object-path /org/gnome/Mutter/DisplayConfig \
  --method org.gnome.Mutter.DisplayConfig.GetCurrentState

gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true
sudo /usr/local/bin/ubuntu-dock-monitors-patch
# logout/login (Wayland não recarrega o shell sem reiniciar a sessão)
```

No magno-note: `eDP-1` = tela embutida, `DP-1` = LG 34", `DP-3` = GWD 16".

Editar o `.conf` depois **não** exige repatch — a lista é lida a cada
(re)criação das docas (troca de monitor, mudança de resolução, login).
Para forçar releitura sem logout: desligue e religue `multi-monitor`.

## Reverter

```bash
sudo /usr/local/bin/ubuntu-dock-monitors-patch --revert
sudo rm -f /etc/apt/apt.conf.d/99-ubuntu-dock-monitors-patch
gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor false
# rede de segurança, se o backup tiver sumido:
# sudo apt reinstall gnome-shell-extension-ubuntu-dock
```

## Observação sobre o painel de Configurações

Com `multi-monitor true`, o combo "Mostrar no" mostra **Todos os monitores** —
é o valor real do dconf; o recorte fica no `.conf`. Se você usar o combo para
escolher um monitor único, ele desliga `multi-monitor` e a whitelist para de
valer (o patch continua instalado, inerte). Para voltar: ligue `multi-monitor`
de novo.
