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
Signed-By: -----BEGIN PGP PUBLIC KEY BLOCK-----
 .
 mQINBGc0vwABEADQtWcyZgno2mdh35eZDzL676CCFLwCnai5HcLTo9l1ZlcNPzvL
 ql6Fj63ZBpq9Y4Ucf6rqNo4uMIRJKC6ybVGhxzzyHijEXwhN+clFhFQPzZQEfyU/
 jEgiOL8R8rAkItlNeumkrvX5Q+TpSkQr8Yh518fMnbKtFnlKEI3Mu3XyDvisGjef
 1ES6HTAEbzHSbBAnp0+mzNPQ1NV5kJtRQ2S7eyd31rwRFKEBHzs8rgwti0af6OeH
 pnBiaWnB2KznRX1ZR2gU6pKFwx8oraaw876IL2WxpPyhwtDZP6rjtM+GIyd8BmWT
 GSOY82RCdaKT+w2/iJl6qYO2fBlphemH8imdhBGbAC1+oGnMjPxOHw6ClTV1aDm6
 nrovFsmyum6F9ou0qA32KIiy4sznPDpGsqIwRcSawDQS9PlCrV02RVtn6uk1Ylpu
 s/Fle29ia8cJDosYq4g+KNiC8Z1a4ripqQlSH/XXiem2iKW0C0S/VOE4v6HiON48
 zQBN/B7q4O+D95YehqboSp02gUQwLOUDk1+WrMDIHsQl76QXY9izrYy5caq9cZBy
 klGDC0SaEZGbNeKywa6GYejQxPuTBbeQY+CHZgxPkOd35KecighIgdWaI9uiXHEI
 wjod7zZVHvQWP20y160WNakYHRJUOUOIUY5C7Yl8cwafNuYJ+J6/ue5JOwARAQAB
 tDdTcG90aWZ5IFB1YmxpYyBSZXBvc2l0b3J5IFNpZ25pbmcgS2V5IDx0dXhAc3Bv
 dGlmeS5jb20+iQJUBBMBCAA+FiEEtCD9N3fM46fwB2tVyFZo32k3UAEFAmc0vwAC
 GwMFCQJRQwAFCwkIBwIGFQoJCAsCBBYCAwECHgECF4AACgkQyFZo32k3UAGSoxAA
 rS4ewvpj0vE9jp3qG7cAM5bIkU6H4/cWBED5/l9n/0kQhPTUeeNKE8T52rbdOard
 jd25J9CsyaItbDJ7LkE6acRm0V/qtmE7XwlrhLcCUe0qEyCeXWXtuGCiTpbBlZG/
 qJCP6AuiEGBmKlh9ToagMUM/yrng68pgVJXWe/b39GP21mrTDu3H56rXd7jrPO2n
 jzlxxhEJq9NxD8+PV5XUFefK2C35idgUhX1yWDEZ9YUBCYPwrBxTr0gEhcIhFZzo
 S30T3lG8oU7X97+Kk4QloiV4zsLH+7Aer/F1AMVRe+MVTlDwLlpnusKwAI+Syy3u
 aqKp2JGR14JmG3w/PsuzhqJ9rJC1UNYUY5tlIpy8Lje+PP7ag36DteSvzuHSNDMa
 feSk2Bve6UKng+zYq0dOLI7NiIQl7KZsHzSGzcskfx3wSdaVw7it3ssvoscul9mM
 uhqz4qoCXCXv4N2t49H1XgQtrZ54s/pJ4V9H2G/Xv85qKBrnlSi5xv43w6KbY1cX
 1upY90GkKwdhWZu+EueIXNvzA1VkquCSuLmlzUdnCZE7iNTRLDfm/A4afnC8f9K0
 z7qRIk/bCQAXTKngHPwd0qG3yD4z/a3F0W/+PNXIwCzCTC6/kr4goP6gxUkN5b2e
 TW2bDjIXULm9fpQsWJ0Y+/zCl69tZHtQ1Nop/3Nrl1M=
 -----END PGP PUBLIC KEY BLOCK-----
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

