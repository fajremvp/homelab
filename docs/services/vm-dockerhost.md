# DockerHost (Servidor de Aplicações)

O `DockerHost` é a VM central responsável por rodar a maioria dos serviços containerizados do Homelab via Docker rodando sobre Debian e gerenciado via Ansible.

## Especificações Técnicas da VM (Proxmox)
Implementação realizada em: 2025-12-27.

| Recurso | Configuração Escolhida | Detalhes / Justificativa |
| :--- | :--- | :--- |
| **ID / Nome** | `105` / `DockerHost` | Start at boot: **Sim**. Add to HA: **Sim**. |
| **OS** | Debian GNU/Linux | ISO: `debian-13.2.0-amd64.netinst` (Rolling/Testing)*. |
| **Kernel** | Linux 6.x | Guest Agent ativado para telemetria no host. |
| **vCPU** | 2 Cores | Type: `host` (Repassa instruções AES-NI da CPU real). |
| **RAM** | 8 GB | Ballooning: **Não** (Desativado para estabilidade de serviços Java/ZFS). |
| **Disco** | 32 GB (SCSI) | Storage: `local-zfs`. <br> **Otimizações:** SSD Emulation (On), Discard (On), IO Thread (On), Async IO (Threads). |
| **Rede** | `vmbr0` (VirtIO) | **VLAN Tag: 30** (Rede SERVER). Firewall do Proxmox: Desligado. |

## Estratégia de Ingress e Proxy Reverso (Traefik)
Implementação realizada em: 2026-01-02.

O DockerHost utiliza o **Traefik** como "Porteiro Único". Nenhuma aplicação expõe portas diretamente para a rede, exceto o próprio Traefik.

* **Versão:** `Traefik v3.6+` (Latest Stable).
* **Portas Expostas:**
    * `80` (HTTP): Redireciona forçadamente para HTTPS.
    * `443` (HTTPS): Terminação SSL (Atualmente Autoassinado, futuro Let's Encrypt).
    * `8080` (Dashboard): **Bloqueada**. O acesso direto foi removido; o dashboard agora é acessível exclusivamente via `https://traefik.home` (protegido por autenticação).

### ⚠️ Compatibilidade Debian 13 (Trixie)
O Docker Engine v29+ (presente no Debian Trixie) rejeita conexões de clientes que tentam negociar APIs muito antigas (<1.44), comportamento padrão do Traefik.
**Regra Obrigatória:** Todo container do Traefik **DEVE** conter a variável de ambiente abaixo para funcionar:

```yaml
environment:
  # Instrui o driver Docker (Moby) a ignorar negociação e usar API 1.45 direto.
  - DOCKER_API_VERSION=1.45
```

### Segurança do Ingress (Socket Proxy)
O Traefik **NÃO** possui acesso direto ao socket do Docker (`/var/run/docker.sock`).
Toda a comunicação passa por um container intermediário (`socket-proxy`) configurado para:
* **Permitir:** Listagem de Containers, Serviços e Redes (`GET`).
* **Bloquear:** Execução de comandos, criação de containers, kill ou stop (`POST`, `DELETE`).
* **Endpoint:** O Traefik acessa a API via TCP: `tcp://socket-proxy:2375`.

## Configuração do Sistema Operacional (Hardening Base)
* **Particionamento:** Disco inteiro (`ext4`).
* **Pacotes Instalados:** Apenas `SSH Server` e `Standard System Utilities`.
* **Rede:**
    * **IP:** Definido IP estático com o OPNsense (10.10.30.10) na (VLAN 30).
    * **DNS:** Configurado via `systemd-resolved` apontando para o AdGuard (`10.10.30.5`).
    * **Domínios:** Resolve `*.home` corretamente. Dependência de `/etc/hosts` removida.
* **Usuário:** `fajre` (Sudoers).
* **SSH:**
    * Porta: `22`.
    * Autenticação: **Somente Chave Pública** (Senha desabilitada em 2025-12-29).
    * Root Login: **Bloqueado**.
* **Defesa Ativa (Fail2Ban):**
    * **Jail SSH:** Ativa com `mode = aggressive`. Backend via Systemd.
    * **Whitelist:** Rede de Gestão (`10.10.10.x`) e Trusted (`10.10.20.x`) ignoradas para evitar auto-bloqueio acidental.
* **Runtime:** Docker CE + Compose Plugin (Instalados).

## Padrão de Diretórios e Persistência
Para manter a organização e facilitar backups, o DockerHost segue estritamente a hierarquia abaixo em `/opt/`:

| Caminho | Propósito | Exemplo de Conteúdo |
| :--- | :--- | :--- |
| `/opt/services` | Aplicações Gerais | `traefik/`, `vaultwarden/`, `whoami/` |
| `/opt/auth` | Identidade e Segurança | `authentik/` |
| `/opt/monitoring` | Observabilidade | `grafana/`, `prometheus/`, `alertmanager/`, `alloy/`, `loki/` |
| `opt/security` | Segurança | `crowdsec/` |
| `/opt/utils` | Scripts e Ferramentas | Scripts de manutenção local |

**Política de Logs:**
O Docker Daemon foi configurado (`/etc/docker/daemon.json`) para rotacionar logs automaticamente.
* **Driver:** `json-file`
* **Max Size:** `10m`
* **Max Files:** `3` (Total 30MB de retenção por container).

## Aplicações e Serviços (Sempre ativos)

* **VM de Aplicações (DockerHost):** `[Debian Stable]`
    * **Justificativa:** Um "servidor" centralizado para rodar todos os aplicativos em contêineres Docker. Isso mantém o Host Proxmox limpo. (Uma VM oferece melhor isolamento; um LXC é mais leve).
    * **Serviços rodando neste Host (Docker):**
        * **Tailscale (VPN Gateway):**
            - **Modo:** Container Docker rodando em `network_mode: host` para evitar duplo encapsulamento e perda de performance.
            - **Função:** Subnet Router para as VLANs de serviço (10, 30, 40).
            - **Automação:** - `AuthKey`: Injetada via Ansible (`.env`) como Reutilizável, permitindo recriação do container sem aprovação manual.
                - `State`: Persistido em `./state` (protegido contra wipe do Ansible).
            - **Networking Helper:** Serviço `tailscale-nat.service` (Systemd) garante que as regras de `iptables` (NAT Masquerade na interface `ens18` e permissão na chain `FORWARD`) sejam aplicadas a cada boot, permitindo que o tráfego da VPN atravesse o firewall restritivo do Docker.
    	* `Stalwart Mail Server`: A escolha definitiva. Servidor moderno escrito em **Rust** (memory-safe). Substitui Postfix/Dovecot/Rspamd por um binário único e eficiente. Suporta JMAP/IMAP/SMTP e consome apenas ~150MB de RAM. Também com aliases. Já aviso que não enviarei e-mails, somente receber (estou ciente da dificuldade de manter a famosa "reputação"). Uso de SMTP Relay externo ou e-mail comum que já uso (Tuta e Proton) caso haja bloqueio da porta 25 pelo ISP.
        * `Nostr Relay (nostr-rs-relay)`: [Implementado em 2026-01-31]
        - **Motivo:** Garantir soberania e resiliência. Caso eu seja banido de relays públicos, continuo com meu próprio relay operando normalmente. Além disso, ele funciona como backup pessoal do meu conteúdo e da minha presença no Nostr, independente de terceiros.
        - **Tecnologia:** Rust (Substituiu a ideia inicial do Strfry/C++ pelo suporte ao whitelist nativo).
        - **Privacidade:** Configurado com *whitelist* de escrita (apenas minha chave privada pode postar).
        - **Acesso:**
            - **Local:** `wss://nostr.home` (Alta performance).
            - **Tor:** Hidden Service `.onion` (Soberania e acesso externo sem abrir portas na WAN).	
      * **Authentik (Identity Provider):** `[DockerHost]`
          - **Local:** `/opt/auth/authentik`
          - **Versão:** `2025.10.3` (Stable).
          - **Banco de Dados:** PostgreSQL 16 e Redis 7 (Dedicados, rede `internal`).
          - **Função:** Centraliza autenticação (SSO) e segurança Zero Trust.
          - **Integração:** Exposto via Traefik (`auth.home`).
          - **Middleware:** Exporta o middleware `authentik@docker` para o Traefik. Qualquer container que adicionar a label `middlewares=authentik@docker` torna-se imediatamente protegido por login, sem precisar implementar autenticação própria.
      * `Vaultwarden` (Gerenciador de senhas):
          - **Local:** `/opt/services/vaultwarden`
          - **Banco de Dados:** SQLite (Arquivo único em `./data`, foco em facilidade de backup).
          - **Integração Vault:** Usa AppRole dedicado para injetar o `ADMIN_TOKEN` na inicialização.
          - **Ingress:**
              - `/`: Acesso direto (necessário para Apps Mobile/Desktop).
              - `/admin`: Protegido via Authentik Middleware (Apenas `infra-admins`).
      * `Syncthing` (Sincronização)
      * `Forgejo`(Pull Mirror): Servidor Git auto-hospedado. Será configurado como um "pull mirror" (somente leitura) que puxa automaticamente as mudanças do GitHub (usado como repositório primário/público).
      * `Forgejo Actions`(CI/CD): Utilizado para rodar pipelines de teste locais (no homelab) sobre o código espelhado, permitindo validar integrações com outros serviços internos.
      * `FreshRSS` (Fonte de informações descentralizadas e distribuídas)
      * `Grafana + Prometheus + Loki` (Observabilidade: Métricas e Logs)
        	- **Política:** Retenção de logs configurada para **7 dias** para evitar que o armazenamento de logs lote o SSD NVMe principal.
      * `ntfy` (Servidor de Notificações): Alternativa soberana ao Discord/Slack. Recebe webhooks do Alertmanager/Grafana e envia push notifications para o celular.
      * `Portfólio pessoal` (Servidor web, via Traefik (também disponível em .onion e IPFS))
      * `Pequeno site` (Servidor web, via Traefik)

* **Resiliência de Boot**: Todos os containers críticos (Vaultwarden, Stalwart) devem ser configurados com restart: always ou restart: on-failure:10. Isso garante que, se tentarem subir antes do Vault estar pronto, eles continuarão tentando até conseguirem a senha.

## Serviços Sob Demanda (Não vão estar sempre ligados)

* **Aplicações Sob Demanda (Docker):** `[DockerHost]`
    * **Justificativa:** Podem rodar no mesmo DockerHost dos serviços "Sempre Ativos", basta ligar e desligar os contêineres conforme necessário (`docker-compose up -d` e `docker-compose down`).
        * `Mattermost`(Alternativa ao Slack)
        * `OnlyOffice`(Alternativa ao Docs)
        * `HedgeDoc`(Anotações e brainstorming em grupo)
        * `Jitsi Meet`(Alternativa ao Meet (para no máximo umas 8 pessoas, somente chamada de áudio, sem video, talvez no máximo so alguém compartilhando a tela))
        * `Servidor de Minecraft`(Survival Vanilla para jogar com até 3 amigos)

## CrowdSec Agent (LAPI)
Implementação realizada em: 2026-01-24.

O CrowdSec atua como o sistema de detecção de intrusão (IDS) baseado em logs.

* **Configuração de Segurança:**
    - **Isolamento de Porta:** A API (LAPI) escuta exclusivamente no IP `10.10.30.10:8080`.
    - **Integração Docker:** Consome metadados via `socket-proxy` (TCP 2375).
* **Monitoramento de Aplicação (Authentik):**
    - **Mapeamento:** O log do Authentik é mapeado via ID estático do container em `/opt/security/crowdsec/acquis.yaml`. 
    - **Atenção:** Em caso de `docker compose up` que gere novo ID, o `acquis.yaml` deve ser revisado.
* **Coleções:** `crowdsecurity/traefik`, `crowdsecurity/http-cve`, `firix/authentik`.

## Gestão de Segredos (Vault Integration)
O DockerHost não armazena senhas de banco de dados em arquivos de texto (`.env` ou `docker-compose.yml`).

* **Mecanismo:** Script de Boot (`start-with-vault.sh`).
* **Trigger:** Serviço Systemd `authentik-vault.service`.
* **Fluxo:**
    1. Lê `SecretID` protegido em `/etc/vault/`.
    2. Autentica no Vault (`vault.home`).
    3. Exporta variáveis de ambiente (ex: `POSTGRES_PASSWORD`) para a RAM.
    4. Executa `docker compose up`.
* **Resiliência:** Se o Vault estiver selado (pós-reboot), o serviço entra em loop de reinício até que o cofre esteja disponível.

## Estratégia de Backup (Restic)
Implementado em: 2026-01-09.

O DockerHost realiza backups diários, criptografados e incrementais para o Backblaze B2.

* **Ferramenta:** Restic (via script `/usr/local/bin/backup-daily.sh`).
* **Agendamento:** Todo dia às 04:00 (Cron).
* **Escopo de Backup:**
    * `/opt/services` (Traefik, Whoami, etc).
    * `/opt/auth` (Authentik, Vaultwarden).
* **Exclusões:** Logs (`*.log`), arquivos temporários de banco (`*.sqlite3-wal`) e caches.
* **Retenção:** 7 dias, 4 semanas, 6 meses.
