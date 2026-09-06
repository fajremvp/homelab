# Runbook — Media Stack

- **Estado:** funcional e validado
- **Data de referência:** 2026-09-05
- **Host:** DockerHost — `10.10.30.10`
- **Orquestração:** Docker Compose + Ansible
- **Repositório:** `homelab`
- **Branch usada durante a implantação:** `feat/media-stack`

---

## 1. Objetivo e escopo

A media stack fornece aquisição automatizada, organização, legendas, catálogo e reprodução local de filmes e séries.

Fluxo funcional:

```text
                        ┌───────────┐
                        │   Seerr   │
                        └─────┬─────┘
                              │ requests
                  ┌───────────┴───────────┐
                  ▼                       ▼
               Radarr                  Sonarr
                  │                       │
                  └──────────┬────────────┘
                             ▼
                         Prowlarr
                    ┌────────┴────────┐
                    │                 │
               indexers        FlareSolverr
                    │          quando necessário
                    └────────┬────────┘
                             ▼
                         qBittorrent
                             │
                    network namespace
                             │
                         Gluetun
                             │
                    ProtonVPN/WireGuard
                             │
                          Internet

qBittorrent
    │
    ▼
/data/torrents/{movies,tv}
    │
    │ hardlink
    ▼
/data/media/{movies,tv}
    │
    ├── Bazarr → legendas
    └── Jellyfin → reprodução
```

A TV/VLAN50 foi removida definitivamente do escopo. O cliente de reprodução é o desktop.

---

# 2. Arquitetura

## 2.1 Serviços

A stack contém:

```text
gluetun
qbittorrent
prowlarr
radarr
sonarr
bazarr
jellyfin
seerr
flaresolverr
```

Imagens configuradas:

```text
qmcgaw/gluetun:latest
lscr.io/linuxserver/qbittorrent:latest
lscr.io/linuxserver/prowlarr:latest
lscr.io/linuxserver/radarr:latest
lscr.io/linuxserver/sonarr:latest
lscr.io/linuxserver/bazarr:latest
jellyfin/jellyfin:latest
ghcr.io/seerr-team/seerr:latest
ghcr.io/flaresolverr/flaresolverr:v3.5.0
```

Versões observadas durante a implantação/validação, sem garantia de permanência devido ao uso de `latest`:

```text
qBittorrent:          5.1.4
Seerr:                3.4.1
Jellyfin:             10.11.11 após atualização
FlareSolverr:         3.5.0
Playback Reporting:   17.0.0
```

---

## 2.2 Redes Docker

Existe uma bridge própria:

```text
media_net
```

Ela **não é `internal: true`**, pois Radarr, Sonarr, Prowlarr, Bazarr, Jellyfin e Seerr precisam acessar serviços externos.

Existe também a rede externa:

```text
proxy
```

usada pelo Traefik.

O padrão é:

```text
Radarr        → media_net + proxy
Sonarr        → media_net + proxy
Prowlarr      → media_net + proxy
Bazarr        → media_net + proxy
Jellyfin      → media_net + proxy
Seerr         → media_net + proxy
Gluetun       → media_net + proxy
FlareSolverr  → media_net
```

FlareSolverr não é publicado pelo Traefik.

qBittorrent não possui namespace de rede próprio:

```yaml
network_mode: service:gluetun
```

Portanto ele usa diretamente as interfaces, rotas e firewall do Gluetun.

---

## 2.3 Reverse proxy e autenticação

Interfaces administrativas passam por:

```text
browser
  ↓ HTTPS
Traefik
  ↓
Authentik ForwardAuth
  ↓
serviço
```

Protegidos pelo Authentik:

```text
https://radarr.home
https://sonarr.home
https://prowlarr.home
https://bazarr.home
https://seerr.home
https://qbittorrent.home
```

Jellyfin é propositalmente diferente:

```text
https://jellyfin.home
```

usa autenticação nativa do Jellyfin, sem ForwardAuth do Authentik.

Motivo: clientes Jellyfin precisam acessar diretamente sua API e um ForwardAuth externo pode quebrar clientes nativos.

Não existe mais porta `8085` publicada diretamente para o qBittorrent.

---

# 3. DNS

Os nomes internos resolvem para o DockerHost:

```text
radarr.home       → 10.10.30.10
sonarr.home       → 10.10.30.10
prowlarr.home     → 10.10.30.10
bazarr.home       → 10.10.30.10
jellyfin.home     → 10.10.30.10
seerr.home        → 10.10.30.10
qbittorrent.home  → 10.10.30.10
```

Isso foi validado com `dig`.

---

# 4. Storage

## 4.1 Disco de mídia

No Proxmox, a VM 105 recebeu:

```text
scsi2
400 GB
local-zfs
backup=0
discard=on
iothread=1
ssd=1
```

O filesystem criado é:

```text
ext4
LABEL=media_disk
UUID=464ec07b-8503-443e-a9d3-e9ead34881cc
```

Capacidade utilizável observada:

```text
~393 GiB
```

---

## 4.2 Persistência do mount

O DockerHost possui em `/etc/fstab`:

```fstab
LABEL=media_disk /mnt/media ext4 defaults,noatime 0 2
```

Nunca deve ser substituído por algo como:

```fstab
/dev/sdb /mnt/media ...
```

ou:

```fstab
/dev/sdc /mnt/media ...
```

A ordem dos devices efetivamente mudou após reboot:

```text
antes: /dev/sdc
depois: /dev/sdb
```

e o mount continuou funcionando por causa do LABEL.

Essa é uma decisão de segurança derivada de um incidente anterior em que mudanças em `/dev/sdX` causaram falha de boot.

---

## 4.3 Layout

Layout final:

```text
/mnt/media/
└── data/
    ├── torrents/
    │   ├── movies/
    │   └── tv/
    └── media/
        ├── movies/
        └── tv/
```

Dentro dos containers Arr/qBit/Bazarr:

```text
/mnt/media/data → /data
```

Jellyfin recebe somente:

```text
/mnt/media/data/media → /media:ro
```

Logo:

```text
qBit:
  /data/torrents/...

Radarr/Sonarr:
  /data/media/...

Jellyfin:
  /media/...
```

O uso de uma única árvore `/data` no mesmo filesystem é deliberado para permitir hardlinks.

---

## 4.4 Permissões

Diretórios da stack e mídia usam:

```text
UID:  1000
GID:  1000
mode: 0775
```

No host isso foi observado como:

```text
fajre:fajre
```

Exemplos validados:

```text
fajre:fajre 775 /opt/services/media/config
fajre:fajre 775 /opt/services/media/config/radarr
fajre:fajre 775 /opt/services/media/config/sonarr
fajre:fajre 775 /mnt/media/data
fajre:fajre 775 /mnt/media/data/torrents
fajre:fajre 775 /mnt/media/data/media
```

Não foram encontrados arquivos divergentes nos primeiros níveis de `/mnt/media/data`.

---

# 5. Configuração persistente em Git/Ansible

## 5.1 Compose

Arquivo fonte:

```text
configuration/dockerhost/services/media/docker-compose.yml
```

Destino no DockerHost:

```text
/opt/services/media/docker-compose.yml
```

Todos os serviços usam:

```yaml
restart: unless-stopped
```

Os containers LinuxServer usam:

```text
PUID=1000
PGID=1000
UMASK=002
TZ=America/Sao_Paulo
```

Jellyfin usa:

```yaml
user: "1000:1000"
```

---

## 5.2 Gluetun

Configuração relevante:

```text
VPN_SERVICE_PROVIDER=protonvpn
VPN_TYPE=wireguard
WIREGUARD_PRIVATE_KEY=${VPN_WIREGUARD_PRIVATE_KEY}

PORT_FORWARD_ONLY=on
VPN_PORT_FORWARDING=on
VPN_PORT_FORWARDING_PROVIDER=protonvpn
```

A antiga configuração:

```text
FIREWALL_OUTBOUND_SUBNETS=10.10.0.0/16
```

foi removida.

Também foi removida a publicação:

```text
10.10.30.10:8085:8080
```

A WebUI do qBit só é acessada atualmente via Traefik.

### Port forwarding dinâmico

Quando Proton entrega uma porta, Gluetun chama a API local do qBittorrent:

```text
http://127.0.0.1:8080/api/v2/app/setPreferences
```

e ajusta:

```json
{
  "listen_port": "<PORTA_PROTON>",
  "current_network_interface": "tun0",
  "random_port": false,
  "upnp": false
}
```

Quando a porta deixa de estar disponível, o DOWN command altera a interface para `lo` e zera a porta.

As portas observadas durante testes mudaram entre reconexões, como esperado. Elas não devem ser documentadas como valores estáticos.

---

## 5.3 Dependência qBittorrent → Gluetun

Configuração final:

```yaml
depends_on:
  gluetun:
    condition: service_healthy
    restart: true
```

Isso garante que operações de Compose envolvendo o Gluetun também reiniciem o qBittorrent quando necessário.

Importante: isso não equivale a um watchdog universal para qualquer falha espontânea do runtime.

---

## 5.4 Playbook de serviços

Arquivo:

```text
configuration/playbooks/dockerhost/services.yml
```

A seção da media stack:

1. sincroniza a stack para:

   ```text
   /opt/services/media
   ```

2. exclui do `rsync --delete`:

   ```text
   .env
   config/
   cache/
   ```

3. garante diretórios persistentes em `1000:1000`, `0775`;

4. executa:

   ```bash
   mountpoint -q /mnt/media
   ```

   antes de criar a árvore de mídia;

5. garante:

   ```text
   /mnt/media/data/torrents/movies
   /mnt/media/data/torrents/tv
   /mnt/media/data/media/movies
   /mnt/media/data/media/tv
   ```

6. gera `/opt/services/media/.env`;

7. sobe a stack com `community.docker.docker_compose_v2`.

### Proteção do mount

O:

```bash
mountpoint -q /mnt/media
```

é uma proteção deliberada.

Se o disco de mídia estiver ausente, o deploy deve **falhar**, em vez de criar `/mnt/media/data` no filesystem raiz e começar a encher o disco do sistema.

Essa proteção já foi testada na prática: o primeiro deploy falhou exatamente nessa etapa enquanto o disco ainda não estava montado.

---

# 6. Segredos

## 6.1 SOPS + age

Arquivo:

```text
configuration/inventory/group_vars/dockerhost/secrets.sops.yaml
```

Segredo da VPN:

```yaml
media_vpn_wireguard_private_key: <secret>
```

O Ansible gera:

```text
/opt/services/media/.env
```

com:

```text
VPN_WIREGUARD_PRIVATE_KEY=...
```

Permissões:

```text
0600
```

e a task usa:

```yaml
no_log: true
```

---

## 6.2 ntfy

O token de acesso do ntfy já existente no SOPS é reutilizado pelo:

```text
Alertmanager
Seerr
```

O ntfy está configurado com autenticação `deny-all`; publicações precisam de Bearer token.

---

## 6.3 Segredos mantidos pelas aplicações

Não foram migrados para SOPS durante este trabalho:

```text
qBittorrent admin password
Radarr API key
Sonarr API key
Jellyfin API keys
Seerr API key
OpenSubtitles.com username/password
SubDL API key
```

Eles persistem dentro dos respectivos diretórios `/config`.

Não devem ser adicionados em texto puro ao repositório.

---

# 7. Configurações manuais — qBittorrent

Acesso:

```text
https://qbittorrent.home
```

## Downloads

```text
Torrent content layout: Original
Add to top of queue: OFF
Do not start automatically: OFF
Torrent stop condition: None

Merge trackers: OFF
Delete .torrent files afterwards: OFF
Pre-allocate disk space: OFF
Append .!qB extension: ON
Keep unselected files in .unwanted: ON
```

## Saving Management

Estado final:

```text
Default Torrent Management Mode:
Manual

Default Save Path:
/data/torrents

Use Subcategories:
OFF

Use Category paths in Manual Mode:
ON
```

Essa última opção foi inicialmente deixada OFF e posteriormente **habilitada**, após observar downloads com categoria `radarr` sendo salvos na raiz de `/data/torrents`.

Categorias:

```text
radarr → /data/torrents/movies
sonarr → /data/torrents/tv
```

Validação posterior:

```text
Obsession
category: radarr
save_path: /data/torrents/movies
auto_tmm: False
```

Um torrent antigo, adicionado antes da alteração, permaneceu em `/data/torrents`; a opção não move torrents existentes retroativamente.

---

## Connection

```text
Peer connection protocol:
TCP + µTP

UPnP/NAT-PMP:
OFF
```

A listening port não é escolhida manualmente. Ela vem da ProtonVPN através do Gluetun.

Limites:

```text
Global connections:       500
Connections per torrent:  100

Global upload slots:      50
Upload slots per torrent: 10
```

Proxy:

```text
None
```

---

## BitTorrent

```text
DHT:                    ON
PeX:                    ON
Local Peer Discovery:   OFF
Encryption:             Allow
Anonymous Mode:         OFF
```

---

## Queue

```text
Torrent Queueing: ON

Maximum active downloads: 3
Maximum active uploads:   8
Maximum active torrents: 10

Do not count slow torrents:
ON
```

---

## Seeding

```text
Ratio limit:       1.0
Seeding time:      48 h
Action:            Stop
```

O runbook **não assume remoção automática dos dados ao atingir esses limites**: o valor confirmado é `Stop`.

---

## Web UI

```text
HTTPS interno: OFF
```

TLS é terminado pelo Traefik.

Configuração obrigatória para integração com Gluetun:

```text
Bypass authentication for clients on localhost:
ON
```

Isso permite que a chamada:

```text
127.0.0.1:8080
```

feita pelo Gluetun modifique a porta sem credenciais.

Não liberar outras redes pelo whitelist.

Manter:

```text
Clickjacking protection: ON
CSRF protection:         ON
```

---

## Advanced

Crítico:

```text
Network interface:
tun0

Optional IP address:
All addresses
```

Também:

```text
Reannounce to all trackers when IP or port changed:
ON
```

O restante do libtorrent foi mantido nos defaults.

---

# 8. Configurações manuais — Prowlarr

Acesso:

```text
https://prowlarr.home
```

## Apps

Radarr e Sonarr são integrados ao Prowlarr.

Conectividade interna:

```text
Prowlarr → http://radarr:7878
Prowlarr → http://sonarr:8989
```

Prowlarr é a fonte central de indexers.

Não é necessário configurar o mesmo indexer manualmente em Radarr/Sonarr.

---

## Indexers

Estado final:

```text
1337x         → FlareSolverr
EZTV          → FlareSolverr
LimeTorrents  → direto
Knaben        → direto
```

Todos passaram nos testes.

1337x e EZTV inicialmente falharam com proteção Cloudflare e passaram após aplicação da tag do FlareSolverr.

---

## FlareSolverr proxy

```text
Name:
FlareSolverr

Host:
http://flaresolverr:8191

Request Timeout:
60

Tag:
flaresolverr
```

A mesma tag é aplicada somente aos indexers que precisam do proxy:

```text
1337x
EZTV
```

Não aplicar globalmente.

---

## Download Client no Prowlarr

Não necessário para o fluxo normal.

Radarr/Sonarr já enviam diretamente para qBittorrent.

---

# 9. Configurações manuais — Radarr

Acesso:

```text
https://radarr.home
```

Root:

```text
/data/media/movies
```

Download Client:

```text
qBittorrent
Host:     gluetun
Port:     8080
Category: radarr
SSL:      OFF
```

Sem Remote Path Mapping.

---

## Naming

```text
Rename Movies:              ON
Replace Illegal Characters: ON
Colon Replacement:          Delete
```

Folder:

```text
{Movie Title} ({Release Year}) {tmdb-{TmdbId}}
```

Arquivo:

```text
{Movie Title} ({Release Year}) {Quality Full}
```

Exemplo validado:

```text
Grand Theft Auto VI An Extended Look (2026) {tmdb-1744462}/
└── Grand Theft Auto VI An Extended Look (2026) WEBDL-1080p.mkv
```

---

## Media Management

```text
Create empty movie folders: OFF
Delete empty folders:       ON

Skip Free Space Check:      OFF
Minimum Free Space:         10 GB

Use Hardlinks instead of Copy:
ON

Import Using Script: OFF
Import Extra Files:  OFF

Unmonitor Deleted Movies:
ON

Propers and Repacks:
Do not Prefer

Analyze video files:
ON

Rescan Movie Folder after Refresh:
After Manual Refresh

Change File Date:
None

Set Permissions:
OFF
```

---

## Quality

Política:

```text
máximo: 1080p
fallback: 720p

sem:
2160p
Remux
SD/480p
CAM/TS/etc.
```

Ordem mantida pelo usuário:

```text
Bluray-1080p
WEB 1080p
WEBDL-1080p
WEBRip-1080p
HDTV-1080p
Bluray-720p
WEB 720p
WEBDL-720p
WEBRip-720p
HDTV-720p
```

O perfil utilizado pelo Seerr aparece como:

```text
HD - 720p/1080p
```

### Quality Definitions

Valores definidos como referência durante a configuração:

```text
720p:
Preferred ≈ 2 GB/h
Max       ≈ 3 GB/h

1080p:
Preferred ≈ 3 GB/h
Max       ≈ 4 GB/h
```

A validação com Chernobyl mostrou que releases Bluray-1080p muito maiores ainda foram aceitos na stack. Portanto esses limites devem ser considerados **um ponto que merece auditoria posterior**, não uma garantia empiricamente validada.

---

## Idioma original

Custom Format usado:

```text
Language: Not Original
```

Estrutura:

```json
{
  "name": "Language: Not Original",
  "includeCustomFormatWhenRenaming": false,
  "specifications": [
    {
      "name": "Not Original Language",
      "implementation": "LanguageSpecification",
      "negate": true,
      "required": false,
      "fields": {
        "value": -2
      }
    }
  ]
}
```

No Quality Profile:

```text
Language: Not Original:     -10000
Minimum Custom Format Score: 0
```

Objetivo:

```text
obra inglesa    → inglês
obra portuguesa → português
obra japonesa   → japonês
obra coreana    → coreano
...
```

Um release multi-áudio pode passar desde que contenha o idioma original.

---

## Download handling

```text
Completed Download Handling:
ON

Failed Download Handling:
Redownload Failed: ON
```

Sem Remote Path Mappings.

---

# 10. Configurações manuais — Sonarr

Acesso:

```text
https://sonarr.home
```

Root:

```text
/data/media/tv
```

Download Client:

```text
Host:     gluetun
Port:     8080
Category: sonarr
SSL:      OFF
```

---

## Naming

```text
Rename Episodes:            ON
Replace Illegal Characters: ON
Colon Replacement:          Delete

Season Folder:
Season {season:00}
```

Arquivo:

```text
{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}
```

Multi-episode:

```text
S01E01-E02
```

Exemplo validado:

```text
Chernobyl/
└── Season 01/
    ├── Chernobyl - S01E01 - 12345 Bluray-1080p Proper.mkv
    ├── Chernobyl - S01E02 - Please Remain Calm Bluray-1080p Proper.mkv
    ├── Chernobyl - S01E03 - Open Wide, O Earth Bluray-1080p Proper.mkv
    ├── Chernobyl - S01E04 - The Happiness of All Mankind Bluray-1080p Proper.mkv
    └── Chernobyl - S01E05 - Vichnaya Pamyat Bluray-1080p Proper.mkv
```

---

## File Management

```text
Unmonitor Deleted Episodes: ON
Use Hardlinks instead of Copy: ON
Analyze video files: ON

Rescan Series Folder after Refresh:
After Manual Refresh

Set Permissions:
OFF
```

---

## Quality

Mesma ordem do Radarr:

```text
Bluray-1080p
WEB 1080p
WEBDL-1080p
WEBRip-1080p
HDTV-1080p
Bluray-720p
WEB 720p
WEBDL-720p
WEBRip-720p
HDTV-720p
```

Sem:

```text
Remux
2160p
480p/SD/DVD
```

Quality Definitions utilizadas como referência:

```text
720p:
Preferred ≈ 1.5 GB/h
Max       ≈ 2.5 GB/h

1080p:
Preferred ≈ 2.5 GB/h
Max       ≈ 3.5 GB/h
```

Mesma ressalva do Radarr: o teste de Chernobyl demonstrou que Bluray-1080p pode resultar em arquivos muito maiores, portanto os limites merecem revisão futura.

Custom Format:

```text
Language: Not Original: -10000
Minimum CF Score:        0
```

---

# 11. Política global de idiomas

Responsabilidades:

```text
Radarr/Sonarr → áudio
Bazarr        → legenda
```

Política final:

```text
Original da obra     Áudio             Legenda
-------------------------------------------------
English                English           en-US
Portuguese             Portuguese        nenhuma
Japanese/French/etc.   idioma original   pt-BR
```

---

# 12. Configurações manuais — Bazarr

Acesso:

```text
https://bazarr.home
```

Integrações:

```text
Sonarr:
http://sonarr:8989

Radarr:
http://radarr:7878
```

API keys respectivas.

Sem Path Mappings.

Sync:

```text
Sync with Sonarr:           ON
Sync Only Monitored Series: ON

Sync with Radarr:           ON
Sync Only Monitored Movies: ON
```

---

## Languages

```text
Single Language:
OFF

Enabled:
English (United States)
Portuguese (Brazil)

Deep analyze audio-track language:
ON
```

Profiles:

### English Original

```text
English (United States)
Exclude Audio: OFF
```

Uso:

```text
áudio English → en-US subtitle
```

### Foreign Original

```text
Portuguese (Brazil)
Exclude Audio: OFF
```

Uso:

```text
idioma original diferente de English/Portuguese
→ pt-BR
```

Não existe profile `Portuguese Original`.

Para obras originalmente em português:

```text
Language Profile:
None
```

Default para novos conteúdos:

```text
Series: English Original
Movies: English Original
```

Foreign content precisa ser alterado para `Foreign Original`.

Português original fica sem profile.

---

## Providers

Ativos:

```text
OpenSubtitles.com
SubDL
Gestdown.info
```

### OpenSubtitles.com

```text
Username/password
Use Hash:                 ON
AI translated subtitles: OFF
Machine translated:      OFF
```

### SubDL

```text
API Key
```

### Gestdown.info

Sem credenciais adicionais registradas.

Anti-Captcha:

```text
None
```

---

## Subtitle Files

```text
Subtitle Folder:
alongside media file

Hearing-impaired extension:
.hi

Encode subtitles to UTF-8:
ON

Change file permissions:
OFF
```

Embedded:

```text
Treat Embedded Subtitles as Downloaded: ON
Ignore PGS:                            ON
Ignore VobSub:                         ON
Ignore ASS:                            OFF
Show Only Desired Languages:           ON
```

Upgrade:

```text
Upgrade Previously Downloaded Subtitles:
OFF
```

Performance:

```text
Adaptive Searching:                    ON
Search providers simultaneously:       OFF
Skip video hash calculation:           OFF
Automatic Audio Synchronization:       OFF
Translator:                            None
```

Não há integração Jellyfin configurada no Bazarr: ela não apareceu na versão/interface utilizada e não foi tratada como requisito. Jellyfin detecta sidecar subtitles por seus scans normais.

---

# 13. Configurações manuais — Jellyfin

Acesso:

```text
https://jellyfin.home
```

Libraries:

```text
Movies:
  /media/movies

TV Shows:
  /media/tv
```

A mídia é montada read-only no container.

---

## Reprodução

Objetivo:

```text
Direct Play sempre que possível
```

Hardware acceleration:

```text
None
```

Não existe `/dev/dri/renderD*` funcional configurado para Jellyfin e transcoding não faz parte do objetivo da stack.

Manter:

```text
Allow subtitle extraction on the fly:
ON
```

Subtitles:

```text
Subtitle mode: Default
Burn subtitles: Auto
Experimental PGS rendering: OFF
Always burn when transcoding: OFF
```

Não existe uma preferência global de legenda capaz de representar toda a política contextual do usuário; Bazarr e as tracks disponíveis fazem esse trabalho.

---

## Metadata / biblioteca

Configuração adotada durante a revisão:

```text
Metadata language: English
Region:            United States

Folder view:             OFF
Specials within seasons: ON
Movie collections:       ON
Show collections:        OFF
External suggestions:    OFF

NFO writing:
OFF/default
```

---

## Networking

```text
HTTP port:    8096
HTTPS:        OFF
Require HTTPS: OFF
Base URL:     vazio
```

TLS:

```text
cliente → HTTPS → Traefik → HTTP → Jellyfin:8096
```

IPv4:

```text
ON
```

Auto Discovery:

```text
OFF
```

Remote connections permaneceram permitidas durante a configuração, sem qualquer exposição direta das portas Jellyfin para a Internet.

Traefik foi observado em:

```text
172.18.0.6
```

e a rede proxy:

```text
172.18.0.0/16
```

Esse é o valor determinado para `Known Proxies`. O histórico, entretanto, não contém uma confirmação inequívoca posterior de que esse campo foi salvo; portanto não deve ser tratado como confirmado sem conferir a GUI.

---

## Plugins

### Playback Reporting

Instalado pela GUI.

Inicialmente:

```text
Jellyfin 10.11.6
Playback Reporting 17.0.0
```

resultou em incompatibilidade.

Após:

```bash
docker compose pull jellyfin
docker compose up -d jellyfin
```

o servidor passou para:

```text
Jellyfin 10.11.11
```

e:

```text
Playback Reporting 17.0.0
```

ficou `Active`.

Foi observado um erro transitório:

```text
database is locked
```

no SQLite do Playback Reporting e uma recriação de tabela após diferença de schema.

Isso não impediu o plugin de carregar.

### Intro Skipper

Repository foi adicionado e o plugin foi posteriormente localizado em:

```text
Plugins → All
```

Ele foi instalado e Jellyfin foi reiniciado.

O arquivo registra a tela completa de opções do Intro Skipper, mas **não registra de forma inequívoca os valores finais que foram salvos depois dessa tela**. Portanto este runbook não inventa esses toggles.

---

# 14. Configurações manuais — Seerr

Acesso:

```text
https://seerr.home
```

## General

Estado configurado para:

```text
Application URL:
https://seerr.home

Image Caching:
OFF

Display Language:
English

Discover Region:
Brazil

Discover Language:
All Languages

Streaming Region:
Brazil

Blocklist Region:
Brazil

Blocklist Language:
All Languages

Blocklist Content with Tags:
OFF

Allow Partial Series Requests:
ON

Allow Special Episodes Requests:
OFF

Hide Available Media:
OFF

Hide Blocklisted Items:
ON

Version Check:
ON
```

Um pedido pode selecionar temporadas específicas.

**Seerr não oferece request de episódio individual.**

Para baixar somente um episódio específico, usar diretamente o Sonarr.

---

## Jellyfin

Interno:

```text
http://jellyfin:8096
```

Externo:

```text
https://jellyfin.home
```

Libraries:

```text
Movies
TV Shows
```

---

## Radarr

```text
Default: ON
4K:      OFF

Internal:
http://radarr:7878

External:
https://radarr.home

Root:
/data/media/movies

Quality Profile:
perfil 720p/1080p

Enable Scan:
ON

Automatic Search:
ON
```

---

## Sonarr

```text
Default: ON
4K:      OFF

Internal:
http://sonarr:8989

External:
https://sonarr.home

Root:
/data/media/tv

Quality Profile:
perfil 720p/1080p

Enable Scan:
ON

Automatic Search:
ON
```

---

## Network

```text
Proxy Support: ON
CSRF:          ON
HTTP(S) Proxy: OFF
```

Seerr não passa pelo Gluetun.

---

# 15. ntfy e alertas de mídia

Topic:

```text
alertas_media
```

O celular está inscrito nesse tópico, separadamente de:

```text
alertas_infra
```

---

## 15.1 Seerr → ntfy

Configuração manual:

```text
Settings
→ Notifications
→ ntfy.sh
```

```text
Enabled: ON

Server Root URL:
http://ntfy:80

Topic:
alertas_media

Username:
vazio

Password:
vazio

Token:
<ntfy_token>

Priority:
Default

Notification Language:
English
```

Eventos úteis habilitados:

```text
Request Available
Request Processing Failed
```

Outros eventos de aprovação/request foram evitados para não gerar spam.

Um request real de Toy Story 5 produziu uma notificação `Available`, validando:

```text
Seerr → ntfy → alertas_media
```

---

# 16. Monitoring persistente

## 16.1 Node Exporter

O pacote Debian:

```text
prometheus-node-exporter
```

ignorava `/mnt` por padrão.

Isso impedia `/mnt/media` de aparecer nas métricas.

Configuração final gerenciada pelo Ansible:

Arquivo:

```text
/etc/default/prometheus-node-exporter
```

Conteúdo:

```text
ARGS="--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)"
```

Essa alteração é aplicada somente ao grupo `dockerhost` no:

```text
configuration/playbooks/hardening_debian.yml
```

e existe handler:

```text
Restart Node Exporter
```

Validação:

```text
node_filesystem_size_bytes{
  device="/dev/sdb",
  fstype="ext4",
  mountpoint="/mnt/media"
}
```

passou a ser exportada.

---

## 16.2 Prometheus

Arquivo:

```text
configuration/dockerhost/monitoring/prometheus/alert.rules.yml
```

Regra final:

```yaml
- name: media_alerts
  rules:
    - alert: MediaDiskUsageHigh
      expr: |
        (
          1 -
          node_filesystem_avail_bytes{
            job="dockerhost-node",
            mountpoint="/mnt/media"
          }
          /
          node_filesystem_size_bytes{
            job="dockerhost-node",
            mountpoint="/mnt/media"
          }
        ) * 100 > 85
      for: 5m
      labels:
        severity: warning
        category: media
      annotations:
        summary: "💾 Media disk acima de 85%"
        description: "/mnt/media está com {{ $value | printf \"%.1f\" }}% de uso."
```

O threshold inicialmente discutido como 80% foi alterado pelo usuário para:

```text
85%
```

Esse é o valor vigente.

---

## 16.3 Alertmanager

Arquivo:

```text
configuration/dockerhost/monitoring/alertmanager/config.yml.j2
```

Estrutura:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'ntfy-infra'

  routes:
    - matchers:
        - category="media"
      receiver: 'ntfy-media'
```

Receivers:

```text
ntfy-infra
→ http://ntfy:80/alertas_infra

ntfy-media
→ http://ntfy:80/alertas_media
```

Ambos:

```text
send_resolved: true
Bearer token: ntfy_token
max_alerts: 5
```

Consequência:

```text
alert sem category=media
→ alertas_infra

alert category=media
→ alertas_media
```

---

## 16.4 Validação

Prometheus:

```bash
docker exec prometheus promtool check rules \
  /etc/prometheus/alert.rules.yml
```

Resultado:

```text
SUCCESS: 13 rules found
```

Alertmanager:

```bash
docker exec alertmanager amtool check-config \
  /etc/alertmanager/config.yml
```

Resultado:

```text
SUCCESS
2 receivers
```

O uso do disco durante o teste era:

```text
~13.49%
```

portanto `MediaDiskUsageHigh` corretamente ficou inativo.

Um alerta manual foi aceito pelo Alertmanager:

```text
MediaTestAlert
category=media
severity=warning
```

Os warnings exibidos pelo `amtool` eram relacionados ao novo parser UTF-8 das annotations, não à criação do alerta.

Forma mais limpa para testes futuros:

```bash
docker exec alertmanager amtool \
  --alertmanager.url=http://localhost:9093 \
  alert add MediaTestAlert \
  category=media \
  severity=warning \
  --annotation='summary="Teste alertas_media"' \
  --annotation='description="Teste manual do roteamento Alertmanager para ntfy"'
```

---

# 17. Deploy

## 17.1 Alterações normais da media stack

No NixOS:

```bash
cd ~/Dev/homelab
git switch feat/media-stack
git pull
```

Editar os arquivos.

Validar diff:

```bash
git diff
```

Commit/push:

```bash
git add <arquivos>
git commit -m "<conventional commit>"
git push
```

No Management LXC:

```bash
ssh root@10.10.10.10
cd /opt/homelab
git pull
```

Deploy dos serviços:

```bash
ansible-playbook configuration/playbooks/dockerhost/services.yml
```

---

## 17.2 Mudanças de monitoring

Para alterações em:

```text
Prometheus
Alertmanager
monitoring compose
```

usar:

```bash
ansible-playbook configuration/playbooks/dockerhost/monitoring.yml
```

Alterações no node_exporter:

```bash
ansible-playbook configuration/playbooks/hardening_debian.yml
```

A configuração do node_exporter e do monitoring exigiu ambos os playbooks.

---

# 18. Procedimentos operacionais

## 18.1 Verificar stack

```bash
cd /opt/services/media
docker compose ps
```

Esperado:

```text
bazarr
flaresolverr
gluetun healthy
jellyfin healthy
prowlarr
qbittorrent
radarr
seerr healthy
sonarr
```

---

## 18.2 Verificar VPN

```bash
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

O IP retornado deve ser da ProtonVPN, não o IP residencial.

---

## 18.3 Verificar qBittorrent

```bash
docker exec gluetun wget -qO- \
  http://127.0.0.1:8080/api/v2/app/preferences \
  | python3 -m json.tool \
  | grep -E '"listen_port"|"current_network_interface"|"upnp"|"random_port"'
```

Esperado:

```text
"current_network_interface": "tun0"
"listen_port": <porta dinâmica Proton>
"random_port": false
"upnp": false
```

---

## 18.4 Reiniciar VPN

### Procedimento recomendado

```bash
cd /opt/services/media
docker compose restart gluetun
```

Com:

```yaml
depends_on:
  gluetun:
    restart: true
```

o Compose também reinicia o qBittorrent.

Depois:

```bash
docker compose ps gluetun qbittorrent
docker exec qbittorrent ip addr show tun0
docker exec gluetun wget -qO- https://ipinfo.io/ip
```

E conferir novamente `listen_port`.

### Evitar

Não usar como procedimento operacional normal:

```bash
docker restart gluetun
```

Nem:

```bash
docker kill gluetun
```

Um restart feito diretamente pelo Docker deixou o qBittorrent preso ao namespace antigo.

Sintoma observado:

```text
gluetun:
tun0 funcionando

qbittorrent:
ip: can't find device 'tun0'
```

e a WebUI interna deixou de responder.

A recuperação foi:

```bash
docker compose up -d gluetun qbittorrent
```

ou:

```bash
docker compose restart gluetun
```

---

# 19. Verificar mount

```bash
findmnt /mnt/media
df -hT /mnt/media
findmnt -no SOURCE,FSTYPE,OPTIONS /mnt/media
```

Estado validado:

```text
ext4
rw,noatime
```

Não interpretar `/dev/sdb` como identidade persistente do disco.

A identidade persistente é:

```text
LABEL=media_disk
UUID=464ec07b-8503-443e-a9d3-e9ead34881cc
```

---

# 20. Verificar hardlinks

Para um arquivo específico:

```bash
stat -c '%i %h %s %n' \
  "<torrent-file>" \
  "<library-file>"
```

Hardlink válido:

```text
mesmo inode
mesmo tamanho
link count >= 2
```

Exemplo real validado com Toy Story 5:

```text
inode: 24772611
links: 2
size: 2047854235
```

tanto em:

```text
/mnt/media/data/torrents/...
```

quanto em:

```text
/mnt/media/data/media/movies/...
```

Chernobyl também teve os cinco episódios confirmados com inodes idênticos e `links=2`.

---

# 21. Como funciona `/torrents`

Enquanto qBittorrent mantém o torrent:

```text
/data/torrents/.../movie.mkv
```

e Radarr/Sonarr importam por hardlink:

```text
/data/media/.../movie.mkv
```

os dois nomes apontam para os mesmos blocos físicos.

Exemplo:

```text
torrents/movie.mkv ─┐
                    ├── inode X
media/movie.mkv ────┘
```

Isso não duplica o espaço.

Quando o link em `torrents` deixa de existir:

```text
media/movie.mkv → inode X
```

a mídia continua existindo, mas qBittorrent não consegue mais seedar aquele conteúdo através daquele caminho.

A política confirmada de qBittorrent é **STOP em ratio 1.0 ou 48h**; remoção automática posterior não foi documentada de forma suficiente para entrar neste runbook como comportamento garantido.

---

# 22. Request operacional

## Filme

Uso normal:

```text
Seerr
→ request
→ Radarr
→ Prowlarr
→ qBittorrent/Gluetun
→ import
→ Bazarr
→ Jellyfin
```

---

## Série

Seerr permite requests parciais por temporada:

```text
Allow Partial Series Requests: ON
```

Para **um episódio individual**, usar Sonarr diretamente.

Seerr não oferece granularidade de episódio individual.

---

# 23. Backups

O backup Restic do DockerHost inclui:

```text
/opt/services
/opt/auth
/opt/monitoring
/opt/security
/opt/utils
/mnt/syncthing/Mirror
```

Logo entram no backup:

```text
/opt/services/media/config/qbittorrent
/opt/services/media/config/prowlarr
/opt/services/media/config/radarr
/opt/services/media/config/sonarr
/opt/services/media/config/bazarr
/opt/services/media/config/jellyfin
/opt/services/media/config/seerr
```

Também entra atualmente:

```text
/opt/services/media/cache/jellyfin
```

porque `/opt/services` inteiro é coberto.

Não entra:

```text
/mnt/media/data
```

Isso é intencional.

Filmes, séries e torrents são considerados recriáveis e não justificam backup para Backblaze B2.

Retenção registrada:

```text
7 daily
4 weekly
6 monthly
```

---

# 24. Logs

Runtime confirmado:

```bash
docker info --format '{{.LoggingDriver}}'
```

Resultado:

```text
json-file
```

Exemplo `gluetun`:

```json
{
  "Type": "json-file",
  "Config": {
    "max-file": "3",
    "max-size": "10m"
  }
}
```

Portanto cada container possui rotação:

```text
10 MB × 3
```

Além disso, Alloy/Loki coleta logs da infraestrutura Docker.

---

# 25. Healthchecks

Healthchecks explícitos/observados:

```text
Gluetun
Seerr
Jellyfin
```

Radarr, Sonarr, Prowlarr, Bazarr e FlareSolverr não receberam healthchecks adicionais durante essa implantação.

Essa foi uma decisão deliberada: não adicionar nove verificações superficiais apenas para verificar que uma porta HTTP responde.

Existe heartbeat genérico da stack de monitoring para Healthchecks.io, mas ele não testa semanticamente cada aplicação de mídia.

---

# 26. Teste de kill-switch realizado

Baseline:

```text
qBittorrent:
interface tun0

Gluetun:
IP público Proton

qBit preferences:
current_network_interface=tun0
UPnP=false
porta Proton
```

Durante o teste:

```bash
docker exec gluetun ip link set tun0 down
```

a tentativa:

```bash
wget https://ipinfo.io/ip
```

deixou de retornar conectividade imediatamente.

Nenhum IP residencial foi observado.

O Gluetun posteriormente recuperou/recriou o túnel.

Isso, junto a:

```text
network_mode: service:gluetun
+
qBittorrent Network Interface = tun0
```

valida a arquitetura de kill-switch.

### Limitação do teste

O comportamento de **autorecovery após um crash real espontâneo do Gluetun** não foi comprovado de forma tão forte quanto o comportamento via Compose.

`docker kill gluetun` é uma parada manual do Docker e não deve ser usado como representação perfeita de um crash runtime.

O procedimento operacional validado é o restart via Compose.

---

# 27. Testes end-to-end realizados

## Radarr

Teste:

```text
Grand Theft Auto VI An Extended Look (2026)
WEBDL-1080p
~1.04 GiB
English
```

Validou:

```text
Prowlarr
→ qBit
→ VPN
→ download
→ Radarr import
→ naming
→ library
```

---

## Sonarr

Teste:

```text
Chernobyl
Season 1
5/5 episodes
Bluray-1080p
~47.8 GiB
English
```

Validou:

```text
Sonarr
→ Prowlarr
→ qBit
→ import
→ naming
→ hardlinks
```

Os cinco pares torrent/library tiveram inode idêntico.

---

## Jellyfin

Após scan:

```text
Movies apareceu
Chernobyl apareceu
5 episódios apareceram
playback funcionou
```

O pipeline de biblioteca e reprodução foi validado.

---

## Seerr

Teste:

```text
Scary Movie VI
```

foi solicitado diretamente pelo Seerr e o usuário confirmou que **todo o fluxo funcionou**.

Isso validou:

```text
Seerr
→ Radarr
→ Prowlarr
→ qBit
→ Gluetun
→ import
→ Jellyfin
→ Seerr Available
```

---

## Bazarr + ntfy + hardlink

Teste posterior:

```text
Toy Story 5
```

resultou em:

```text
Toy Story 5 ... WEBRip-1080p.mp4
Toy Story 5 ... WEBRip-1080p.en.hi.srt
```

A notificação `Available` chegou ao `alertas_media`.

O filme também teve hardlink confirmado:

```text
inode 24772611
links 2
```

---

## Category path

Após habilitar:

```text
Use Category paths in Manual Mode: ON
```

novo download:

```text
Obsession
```

ficou em:

```text
/data/torrents/movies
```

confirmando a correção.

---

# 28. Troubleshooting

## 28.1 Deploy falha em `mountpoint -q /mnt/media`

### Sintoma

```text
TASK [Verificar mountpoint da mídia]
FAILED rc=1
```

### Causa

O disco de mídia não está montado.

### Diagnóstico

```bash
lsblk -f
findmnt /mnt/media
cat /etc/fstab
```

### Correção

Garantir:

```fstab
LABEL=media_disk /mnt/media ext4 defaults,noatime 0 2
```

e:

```bash
sudo mount -a
mountpoint /mnt/media
```

Não remover o guard do Ansible.

---

## 28.2 FlareSolverr image not found

### Erro

```text
ghcr.io/flaresolverr/flaresolverr:3.5.0: not found
```

### Causa

Tag incorreta.

### Correção

```text
ghcr.io/flaresolverr/flaresolverr:v3.5.0
```

---

## 28.3 qBittorrent API retorna 403

### Sintoma

Gluetun consegue obter a porta Proton, mas:

```text
/api/v2/app/setPreferences
403 Forbidden
```

### Causa

API local exige autenticação.

### Correção

qBittorrent:

```text
Tools
→ Options
→ Web UI
→ Bypass authentication for clients on localhost
→ ON
```

---

## 28.4 Gluetun recebe porta, mas qBit ainda não responde

### Sintoma

```text
Connection refused
```

logo após restart.

### Causa

Race de inicialização: Gluetun recebe a porta antes de qBittorrent terminar de subir.

### Verificação final

Consultar:

```bash
docker exec gluetun wget -qO- \
  http://127.0.0.1:8080/api/v2/app/preferences \
  | grep -o '"listen_port":[0-9]*'
```

Se o valor for igual à porta Proton, a sincronização foi concluída apesar dos erros iniciais.

---

## 28.5 `qbittorrent.home` retorna Bad Gateway

### Causa observada

Gluetun havia sido reiniciado separadamente e qBittorrent continuava preso ao namespace antigo.

### Correção

```bash
docker compose restart gluetun
```

aguardar `healthy`; com o `depends_on.restart: true`, qBit é reiniciado adequadamente.

Alternativamente:

```bash
docker compose up -d gluetun qbittorrent
```

---

## 28.6 qBit sem `tun0` após `docker restart gluetun`

### Sintoma

```text
docker exec qbittorrent ip addr show tun0
ip: can't find device 'tun0'
```

### Causa

qBit permaneceu ligado ao namespace antigo.

### Correção

Não administrar Gluetun isoladamente com `docker restart`.

Usar Compose.

---

## 28.7 Torrent com categoria `radarr` salva em `/data/torrents`

### Sintoma

```text
category: radarr
save_path: /data/torrents
auto_tmm: False
```

mesmo com:

```text
radarr → /data/torrents/movies
```

### Causa

```text
Default Torrent Management Mode: Manual
Use Category paths in Manual Mode: OFF
```

### Correção final

```text
Use Category paths in Manual Mode:
ON
```

Novos torrents foram corretamente para:

```text
/data/torrents/movies
```

---

## 28.8 Prowlarr bloqueado por Cloudflare

### Sintomas

```text
Unable to access 1337x.to, blocked by CloudFlare Protection.
```

e equivalente para EZTV.

### Correção

FlareSolverr:

```text
http://flaresolverr:8191
tag: flaresolverr
```

Aplicar tag aos indexers:

```text
1337x
EZTV
```

Não aos demais.

---

## 28.9 `/mnt/media` não aparece no Prometheus

### Causa

O node_exporter Debian excluía mounts em `/mnt`.

### Correção

Persistir em:

```text
/etc/default/prometheus-node-exporter
```

via Ansible:

```text
--collector.filesystem.mount-points-exclude=^/(dev|proc|run|sys|var/lib/docker/.+|var/lib/containers/storage/.+)($|/)
```

---

## 28.10 Playback Reporting incompatível

### Sintoma

Plugin não carrega no Jellyfin 10.11.6.

### Correção executada

Atualizar Jellyfin para 10.11.11.

Depois:

```text
Playback Reporting 17.0.0
Active
```

---

# 29. Decisões e justificativas

## VPN somente no qBittorrent

Radarr/Sonarr/Prowlarr/etc. não precisam sair pela Proton.

Benefícios:

```text
menos complexidade
menos problemas de API/metadata
VPN aplicada somente ao tráfego BitTorrent
```

---

## qBit compartilha o namespace do Gluetun

```yaml
network_mode: service:gluetun
```

Isso impede um caminho de rede independente do qBit.

Somado ao:

```text
Network Interface = tun0
```

forma duas camadas contra fallback acidental pela WAN.

---

## Sem UPnP

O encaminhamento vem da ProtonVPN, não do roteador.

```text
UPnP/NAT-PMP = OFF
```

---

## Layout único `/data`

Escolhido para possibilitar:

```text
hardlinks
atomic filesystem operations
sem duplicação de mídia durante seeding
```

---

## Disco identificado por LABEL/UUID

Nunca depender de `/dev/sdX`.

Essa decisão foi validada por uma troca real de nomes de devices após reboot.

---

## Jellyfin read-only

Jellyfin é consumidor da biblioteca.

```text
Radarr/Sonarr/Bazarr → administram arquivos
Jellyfin             → lê/reproduz
```

---

## Sem transcoding planejado

O objetivo é conteúdo até 1080p e Direct Play no desktop.

Hardware acceleration não foi configurada.

---

## Sem Authentik na frente do Jellyfin

Preserva compatibilidade com a API e clientes Jellyfin.

---

## FlareSolverr somente quando necessário

Evita custo de Chromium e complexidade sem benefício para indexers que funcionam diretamente.

---

## Áudio original

Uma única política funciona para qualquer país:

```text
original language obrigatório
```

em vez de manter regras separadas para English, Portuguese, Japanese etc.

---

## Bazarr separado da escolha de áudio

```text
Radarr/Sonarr → áudio original
Bazarr        → legenda
```

Isso evita misturar responsabilidades.

---

## Não fazer backup da mídia

```text
/config → B2
/media  → não
```

As configurações são difíceis de reconstruir; mídia/torrents são grandes e recriáveis.

---

## TV/VLAN50

Integração descartada depois de troubleshooting sem sucesso.

Estado final:

```text
não faz parte da arquitetura
desktop é o único cliente
```

---

# 30. Problemas encontrados e soluções

Resumo cronológico relevante, sem transformar cada tentativa em procedimento:

| Problema                                            | Causa                                    | Solução final                                     |
| --------------------------------------------------- | ---------------------------------------- | ------------------------------------------------- |
| Media stack antiga removida em fevereiro            | Reestruturação anterior                  | Stack refeita no padrão atual de Git/Ansible/SOPS |
| Boot/storage anteriormente dependente de `/dev/sdX` | Ordem de devices muda                    | `LABEL=media_disk`                                |
| Ansible abortou ao instalar stack                   | `/mnt/media` não montado                 | Criado disco 400 GB + ext4 + fstab                |
| FlareSolverr não fazia pull                         | Tag `3.5.0` inexistente                  | `v3.5.0`                                          |
| Authentik retornava Unauthorized                    | Apps/providers ainda não configurados    | Applications/Proxy Providers criados              |
| Gluetun recebia porta mas API qBit dava 403         | localhost exigia auth                    | Localhost bypass ON                               |
| qBit ficou inacessível após restart                 | namespace antigo                         | restart via Compose                               |
| 1337x/EZTV bloqueados                               | Cloudflare                               | FlareSolverr via tag                              |
| Torrent ignorava folder da categoria                | Manual mode + category paths OFF         | `Use Category paths in Manual Mode = ON`          |
| `/mnt/media` não tinha métricas                     | node_exporter excluía `/mnt`             | override persistido via Ansible                   |
| Playback Reporting incompatível                     | Jellyfin 10.11.6                         | Jellyfin 10.11.11                                 |
| Intro Skipper aparentemente ausente                 | usuário estava em Installed, não All     | encontrado no catálogo All                        |
| TV/VLAN50                                           | integração não funcionou após tentativas | removida do escopo                                |

---

# 31. Pontos deliberadamente não implementados / melhorias futuras

Estes itens foram discutidos, mas **não fazem parte do estado atual confirmado**.

## Pinning de imagens

Hoje quase tudo usa:

```text
latest
```

O upgrade Jellyfin:

```text
10.11.6 → 10.11.11
```

demonstrou o risco de version drift.

Melhoria futura:

```text
pin de versões Docker
```

---

## Backup SQLite consistente

Restic cobre os diretórios `/config`, mas as aplicações ficam em execução enquanto os arquivos SQLite são copiados.

Melhoria futura:

```text
backup application-aware
ou
sqlite backup
ou
quiesce controlado
```

---

## Cache Jellyfin no Restic

Atualmente:

```text
/opt/services/media/cache/jellyfin
```

entra por estar dentro de `/opt/services`.

Pode ser excluído futuramente.

---

## Monitor VPN semanticamente

Ainda não existe alerta específico que diga:

```text
Gluetun está UP mas túnel VPN não funciona
```

Um simples alerta de container não é suficiente.

---

## Healthchecks individuais

Não foram adicionados para todos os Arrs.

A decisão atual é evitar checks HTTP pouco significativos.

---

## Alerta duplicado de disco

Existe um alerta genérico de pouco espaço na infraestrutura e agora existe:

```text
MediaDiskUsageHigh >85%
```

Se o alerta genérico também cobrir `/mnt/media`, em uso muito alto podem surgir:

```text
alertas_media
+
alertas_infra
```

para o mesmo disco.

A exclusão de `/mnt/media` da regra genérica foi identificada como melhoria, mas não foi aplicada no histórico.

---

## Quality Definitions

Chernobyl mostrou que:

```text
Bluray-1080p
```

pode resultar em episódios de aproximadamente 8–13 GiB e temporada de ~47.8 GiB.

Como o disco possui ~393 GiB úteis, os limites de tamanho devem ser revisitados se esse padrão se repetir.

---

# 32. Checklist de saúde

Para uma verificação rápida:

```bash
cd /opt/services/media

docker compose ps

findmnt /mnt/media
df -hT /mnt/media

docker exec gluetun wget -qO- https://ipinfo.io/ip

docker exec qbittorrent ip addr show tun0

docker exec gluetun wget -qO- \
  http://127.0.0.1:8080/api/v2/app/preferences \
  | python3 -m json.tool \
  | grep -E '"listen_port"|"current_network_interface"|"upnp"|"random_port"'

docker info --format '{{.LoggingDriver}}'
```

Estado saudável:

```text
/mnt/media montado em ext4
Gluetun healthy
IP público = Proton
qBit possui tun0
qBit interface = tun0
listen_port > 0 e corresponde ao Proton
UPnP = false
containers Up
```

Para monitoring:

```bash
docker exec prometheus promtool check rules \
  /etc/prometheus/alert.rules.yml

docker exec alertmanager amtool check-config \
  /etc/alertmanager/config.yml
```

---

# 33. Estado final

```text
Storage                  ✅
Mount persistente        ✅
Hardlinks                ✅
Docker/Ansible           ✅
SOPS VPN                 ✅
Traefik                  ✅
Authentik admin UIs      ✅
Prowlarr                 ✅
FlareSolverr             ✅
Radarr                   ✅
Sonarr                   ✅
qBittorrent              ✅
Gluetun/ProtonVPN        ✅
Port forwarding          ✅
tun0 binding             ✅
Kill-switch              ✅ validado funcionalmente
Bazarr                   ✅
en-US subtitles          ✅ testado
Jellyfin                 ✅
Playback                 ✅
Playback Reporting       ✅
Intro Skipper            ✅ instalado
Seerr                    ✅
Seerr end-to-end         ✅
ntfy alertas_media       ✅
Prometheus media disk    ✅
Alertmanager routing     ✅
Log rotation             ✅
Restic config backup     ✅
TV/VLAN50                — removida do escopo
4K                       — fora do escopo
Transcoding              — fora do escopo
Backup da mídia          — intencionalmente fora do escopo
```

A stack está apta para uso normal. Mudanças futuras devem ser tratadas como manutenção/hardening, não como requisitos pendentes da implantação original.
