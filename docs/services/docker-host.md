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
    * **IP:** Atribuído via DHCP (VLAN 30).
    * **DNS:** Temporário (`1.1.1.1`) até implementação do AdGuard local.
* **Usuário:** `fajre` (Sudoers).
* **SSH:**
    * Porta: `22`.
    * Autenticação: **Somente Chave Pública** (Senha desabilitada em 2025-12-29).
    * Root Login: **Bloqueado**.
* **Runtime:** Docker CE + Compose Plugin (Instalados).

## Padrão de Diretórios e Persistência
Para manter a organização e facilitar backups, o DockerHost segue estritamente a hierarquia abaixo em `/opt/`:

| Caminho | Propósito | Exemplo de Conteúdo |
| :--- | :--- | :--- |
| `/opt/traefik` | Ingress & Edge | `docker-compose.yml`, `acme.json` |
| `/opt/services` | Aplicações Gerais | `whoami/`, `stirling-pdf/`, `syncthing/` |
| `/opt/auth` | Identidade e Segurança | `authentik/`, `vaultwarden/` |
| `/opt/monitoring` | Observabilidade | `grafana/`, `prometheus/`, `crowdsec/` |
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
    	* `Stalwart Mail Server`: A escolha definitiva. Servidor moderno escrito em **Rust** (memory-safe). Substitui Postfix/Dovecot/Rspamd por um binário único e eficiente. Suporta JMAP/IMAP/SMTP e consome apenas ~150MB de RAM. Também com aliases. Já aviso que não enviarei e-mails, somente receber (estou ciente da dificuldade de manter a famosa "reputação"). Uso de SMTP Relay externo ou e-mail comum que já uso (Tuta e Proton) caso haja bloqueio da porta 25 pelo ISP.
    	* `Nostr Relay (Strfry)`: Servidor de retransmissão de alta performance escrito em C++. Configurado com *whitelist* de escrita (apenas sua chave privada pode postar/fazer backup) e leitura pública. Garante soberania dos dados e resistência à censura. Será exposto também via Tor (Onion Service).
      * **Authentik (Identity Provider):** `[DockerHost]`
          - **Local:** `/opt/auth/authentik`
          - **Versão:** `2025.10.3` (Stable).
          - **Banco de Dados:** PostgreSQL 16 e Redis 7 (Dedicados, rede `internal`).
          - **Função:** Centraliza autenticação (SSO) e segurança Zero Trust.
          - **Integração:** Exposto via Traefik (`auth.home`).
          - **Middleware:** Exporta o middleware `authentik@docker` para o Traefik. Qualquer container que adicionar a label `middlewares=authentik@docker` torna-se imediatamente protegido por login, sem precisar implementar autenticação própria.
      * **HashiCorp Vault (Gerenciador de Segredos):** `[DockerHost]`
          - **Local:** `/opt/auth/vault`
          - **Versão:** `1.21.1` (Raft Storage).
          - **Ingress:** `https://vault.home` (Protegido por Authentik).
          - **Função:** Armazenamento seguro de segredos (API Keys, Senhas de Banco).
          - **Política de Boot:** O serviço inicia selado. Requer intervenção manual (Unseal com 3 chaves) após cada reboot do host.
      * `Vaultwarden` (Gerenciador de senhas)
      * `Syncthing` (Sincronização)
      * `Forgejo`(Pull Mirror): Servidor Git auto-hospedado. Será configurado como um "pull mirror" (somente leitura) que puxa automaticamente as mudanças do GitHub (usado como repositório primário/público).
      * `Forgejo Actions`(CI/CD): Utilizado para rodar pipelines de teste locais (no homelab) sobre o código espelhado, permitindo validar integrações com outros serviços internos.
      * `FreshRSS` (Fonte de informações descentralizadas e distribuídas)
      * `Grafana + Prometheus + Loki` (Observabilidade: Métricas e Logs)
        	- **Política:** Retenção de logs configurada para **7 dias** para evitar que o armazenamento de logs lote o SSD NVMe principal.
      * `ntfy` (Servidor de Notificações): Alternativa soberana ao Discord/Slack. Recebe webhooks do Alertmanager/Grafana e envia push notifications para o celular.
      * `Portfólio pessoal` (Servidor web, via Traefik (também disponível em .onion e IPFS))
      * `Pequeno site` (Servidor web, via Traefik)

* **Bitcoin Core (Full Node) (Sem depender de intermediários e terceiros):** `[VM Dedicada]`
    * **Justificativa:** Alto uso de I/O de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.
    * **Armazenamento:** Montado no **SSD SATA Dedicado**. Isso protege o NVMe principal de desgaste e latência.

* **Terraform / Ansible / Restic:** `[LXC Alpine - Gerenciamento]`
    * **Justificativa:** Centraliza as ferramentas de automação, IaC e backup. O **Terraform** será usado para *provisionar* a infraestrutura (VMs, LXCs) de forma declarativa. O **Ansible** será usado para *configurar* o software *dentro* dessas VMs (instalar pacotes, aplicar hardening). O **Restic** gerencia os scripts de backup de dados. Rodarão a partir de um LXC "admin" dedicado.

* **Resiliência de Boot**: Todos os containers críticos (Vaultwarden, Stalwart) devem ser configurados com restart: always ou restart: on-failure:10. Isso garante que, se tentarem subir antes do Vault estar pronto, eles continuarão tentando até conseguirem a senha.

## Serviços Sob Demanda (Não vão estar sempre ligados)

* **Aplicações Sob Demanda (Docker):** `[DockerHost]`
    * **Justificativa:** Podem rodar no mesmo DockerHost dos serviços "Sempre Ativos", basta ligar e desligar os contêineres conforme necessário (`docker-compose up -d` e `docker-compose down`).
        * `Mattermost`(Alternativa ao Slack)
        * `OnlyOffice`(Alternativa ao Docs)
        * `HedgeDoc`(Anotações e brainstorming em grupo)
        * `Jitsi Meet`(Alternativa ao Meet (para no máximo umas 8 pessoas, somente chamada de áudio, sem video, talvez no máximo so alguém compartilhando a tela))
        * `Servidor de Minecraft`(Survival Vanilla para jogar com até 3 amigos)
