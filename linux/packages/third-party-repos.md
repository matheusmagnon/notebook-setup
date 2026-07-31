# Repositórios de terceiros

Capturado de `/etc/apt/sources.list.d/` em 2026-07-30 (Ubuntu 25.10).
Os pacotes que dependem destes repos estão marcados em `apt.txt` — sem o repo,
o `40-packages.sh` simplesmente pula o pacote e avisa.

## `cursor.sources`

```
### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# You may comment out this entry, but any other modifications may be lost.
Types: deb
URIs: https://downloads.cursor.com/aptrepo
Suites: stable
Components: main
Architectures: amd64,arm64
Signed-By: /usr/share/keyrings/anysphere.gpg
```

## `google-chrome.sources`

```
Types: deb
URIs: https://dl.google.com/linux/chrome/deb/
Suites: stable
Components: main
Signed-By: /etc/apt/trusted.gpg.d/google-chrome.gpg
Enabled: no
```

## `spotify.sources`

```
Types: deb
URIs: https://repository.spotify.com
Suites: stable
Components: non-free
Signed-By: <chave pública PGP do Spotify inline — omitida por brevidade>
Enabled: no
```

## `tailscale.sources`

```
Types: deb
URIs: https://pkgs.tailscale.com/stable/ubuntu/
Suites: plucky
Components: main
Signed-By: /usr/share/keyrings/tailscale-archive-keyring.gpg
Enabled: no
```

## `warpdotdev.sources`

```
### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# You may comment out this entry, but other modifications to the file may be lost.
Types: deb
URIs: https://releases.warp.dev/linux/deb
Suites: stable
Components: main
Architectures: amd64
Signed-By: /etc/apt/trusted.gpg.d/warpdotdev.gpg
```

## `antigravity.list`

```
deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main
```

## `cloudflared.list`

```
deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main
```

