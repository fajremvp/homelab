# Changelog

Todas as mudanças notáveis serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto adere ao versionamento semântico (onde aplicável).

## [Unreleased]
### Planejado

- Organizar cabos
- Fazer uma bancadinha/rack pra deixar tudo
- Encontrar outro Nobreak.
- Colocar consulta de DNS do modem para meus próprios.
- Automatizar testes de alertas.
- Saber se um container caiu, cAdvisor...
- Alertas de Segurança: Implementar regras no Loki (Ruler) para notificar via Ntfy uso de `sudo` e falhas de SSH.

---
## [2026-02-19] - Otimização de Memória e Firewall (OrangeShadow)
### Adicionado (Added)
- **System Tuning (VM 107):** Swap de 2GB e `vm.swappiness=10` configurados para proteção contra OOM e estabilidade do cache de banco de dados.
- **Zero Trust Local:** UFW ativado com regras estritas (Apenas SSH e Porta 9100 de origem mapeada), fechando portas P2P de Clearnet para forçar uso do Tor.
### Alterado (Changed)
- **Documentação Operacional:** Adicionado roteiro de expansão de memória (16GB) para as fases de IBD (Initial Block Download) de ambos os nós (BTC e XMR), com provisionamento de limites no Systemd.

## [2026-02-18] - Nova VM (OrangeShadow) e Hardening
### Adicionado (Added)
- **VM OrangeShadow (ID 107):** Servidor dedicado para Full Nodes (Bitcoin/Monero). Configurado com Debian 13, Disk Passthrough (2TB SSD) e Rede Tor.
- **Ansible Automation:**
    - Atualizado `hosts.ini` e `hardening_debian.yml` para suportar o novo nó.
    - Novo script de backup "cirúrgico" no `setup_backup.yml` que exclui dados da blockchain e preserva apenas carteiras.
- **Observabilidade:** Adicionado target `bitcoin-node` ao Prometheus para ver no Dashboard Grafana.

### Corrigido (Fixed)
- **Monitoring Playbook:** Corrigida falha na execução do `monitoring.yml` que não solicitava a variável `ntfy_token` necessária para o template do Alertmanager.

## [2026-02-16] - File Browser Rollback & Syncthing Hardening
### Removido (Removed)
- **File Browser:** Descontinuada a implementação devido a falhas persistentes na integração de SSO (Proxy Auth) com o Authentik. Containers e configurações removidos via Ansible.

### Alterado (Changed)
- **Syncthing Topology:** Revertida a configuração de pastas para **Send Only** (Clientes) e **Receive Only** (Servidor), garantindo isolamento estrito de dados e prevenindo propagação de exclusões acidentais.
- **Documentation:** Atualizado `vm-dockerhost.md` com a especificação do disco secundário de 100GB.

## [2026-02-15] - CrowdSec Stability Fix, Actual Budget Implementation and Syncthing Implementation
### Corrigido (Fixed)
- **CrowdSec:** Resolvido problema crítico de conectividade ("Network Unreachable") causado por corrupção de estado de rede do Docker.
    - **Ação:** Implementado procedimento de `force-recreate` para garantir que o container receba novas interfaces de rede em caso de falha de comunicação DNS.
    - **Resultado:** Comunicação restabelecida entre LAPI (DockerHost) e Bouncer (OPNsense).
- **Syncthing Permission Loop:** Resolvido *Crash Loop* do container Syncthing causado por permissões incorretas no volume de configuração (`/opt/services/syncthing/config`).
    - **Fix:** Adicionada tarefa no Ansible para forçar `owner: 1000:1000` antes da inicialização do container.

### Adicionado (Added)
- **Finanças (Actual Budget):** Implementado serviço de gestão financeira pessoal.
    - **Stack:** Container `actual-server` (Imagem Oficial GHCR) rodando na porta 5006.
    - **Segurança:** Criptografia End-to-End (E2E) ativada na aplicação. Middleware Authentik **não** aplicado para garantir compatibilidade com App Mobile e Sync nativo.
    - **Armazenamento:** Volume persistente em `/opt/services/actualbudget/data` (SQLite), coberto pelo backup diário do Restic.
- **Data Synchronization (Syncthing):** Implementado Hub Central de sincronização de arquivos.
    - **Hardware:** Adicionado disco virtual de 100GB (SCSI 1) dedicado a dados brutos ("Cold Storage").
    - **Storage Strategy:** Implementada montagem via **UUID** com flag `nofail` para prevenir falhas de boot.
    - **Arquitetura:** Configuração "Hub-and-Spoke". Server atua como repositório central (`Receive Only` com Versionamento), enquanto clientes (Arch, M55) enviam dados (`Send Only`).
    - **Segurança:** GUI protegida por Authentik (Middleware) + Senha Interna. Tráfego de dados isolado na porta 22000.

## [2026-02-13] - Fragmentação do Playbook Manage_Stacks
### Alterado (Changed)
- **Ansible Playbook (`manage_stacks.yml`):** Fragmentado em múltiplos arquivos menores.
- **Objetivo:** Evitar ter que rodar todo o playbook para pequenas alterações e facilitar o gerenciamento de tokens, senhas e variáveis sensíveis.

## [2026-02-12] - Decomposição de Stack de Mídia
### Removido (Removed)
- **Serviços (Containers):** Removida a Stack completa de mídias: Jellyfin, Jellyseerr, Radarr, Sonarr, Bazarr, Prowlarr, FlareSolverr, Gluetun e qBittorrent.
- **Armazenamento:** Removido o disco secundário de 500GB (SCSI 1) do DockerHost e o ponto de montagem `/mnt/media`.
- **Rede:** Removidas as regras de firewall de tráfego interno (Inter-VLAN) entre a VLAN 50 (IOT) e a porta 8096 do DockerHost.

### Alterado (Changed)
- **Otimização de Recursos:** Liberação de 500GB de storage no `local-zfs` e redução do overhead de CPU/RAM no DockerHost.
## [2026-02-11] - Infrastructure Stabilization & Boot Recovery
### Corrigido (Fixed)
- **Boot Failure (Emergency Mode):** Resolvida falha crítica de inicialização do DockerHost.
    - *Causa:* O Proxmox alterou a ordem dos discos virtuais (SCSI) após um reboot. O disco de boot (32GB) assumiu `/dev/sda` e o sistema tentou montá-lo como se fosse o disco de dados `/mnt/media`, causando pânico no systemd (`Dependency failed for local-fs.target`).
    - *Correção:* Alterada a estratégia de montagem no Ansible para utilizar `LABEL=media_disk` (UUID/Label) em vez do caminho do dispositivo (`/dev/sda`), garantindo persistência independente da ordem de hardware.

## [2026-02-10] - Implementation of Media Stack
### Adicionado (Added)
- **Storage:** Adicionado disco virtual de 500GB ao DockerHost, formatado em `ext4` e montado em `/mnt/media`.
- **Media Stack (Arr):** Implementação completa da suíte de automação de mídia via Docker Compose:
    - **Serviços:** Jellyfin, Jellyseerr, Radarr, Sonarr, Bazarr, Prowlarr.
    - **Download:** qBittorrent roteado através de VPN.
    - **Privacidade:** Container `gluetun` atuando como Gateway VPN (ProtonVPN WireGuard) com *Kill Switch* e *Port Forwarding* (NAT-PMP).
- **Ansible:**
    - Criado playbook `setup_storage.yml` para gestão de discos.
    - Atualizado `manage_stacks.yml` para injetar chave privada WireGuard via prompt seguro.

### Corrigido (Fixed)
- **Port Conflict:** Alterada porta externa do qBittorrent/Gluetun para `8085` para resolver conflito com a LAPI do CrowdSec na porta `8080`.
- **Traefik Routing (Split-Brain):** Resolvido erro `504 Gateway Timeout` nos serviços de mídia.
    - *Causa:* Os containers possuíam duas interfaces de rede (`media_net` e `proxy`). O Traefik tentava rotear pelo IP da rede interna inacessível.
    - *Solução:* Forçada a rede de saída via label `traefik.docker.network=proxy` em todos os serviços.
## [2026-02-08] - Refatoração Estrutural e Correção de Rede
### Adicionado (Added)
- **Dead Man's Switch (Healthchecks.io):** Implementado monitoramento de disponibilidade externo.
    - Container leve (`curlimages/curl`) no DockerHost envia "heartbeats" a cada 5 minutos.
    - Política de Alerta: Notificação imediata via e-mail se o servidor deixar de responder por mais de 7 minutos (5m intervalo + 2m tolerância).
    - Segurança: UUID do serviço injetado via Ansible Prompt/Environment, mantendo o repositório público sanitizado.

### Alterado (Changed)
- **Estrutura de Diretórios (DockerHost):** Reorganização massiva dos serviços no servidor e no repositório.
    - Migrado de estrutura plana (`/opt/traefik`, `/opt/vaultwarden`) para estrutura semântica:
        - `/opt/services/`: Aplicações gerais (Traefik, Vaultwarden, Nostr, Whoami, Tailscale).
        - `/opt/auth/`: Serviços de Identidade (Authentik).
    - Objetivo: Facilitar políticas de backup granulares e permissões.
- **Automação Ansible:** Atualizado playbook `manage_stacks.yml` para utilizar `synchronize` com a nova estrutura de pastas, mantendo a persistência de dados (`--exclude=data/`).

### Corrigido (Fixed)
- **CrowdSec Network Isolation:** Resolvido incidente onde o container `crowdsec` perdeu a conexão com a rede bridge `proxy` após a implementação das regras de NAT da VPN.
    - Solução: `force-recreate` do container para reaplicar as regras de iptables do Docker e reatar a interface de rede.
## [2026-02-02] - SIEM, VPN Metrics & Backup Integrity
### Adicionado (Added)
- **Backup Consistente (Authentik):** Implementado `pg_dump` automatizado no script de backup diário. O banco PostgreSQL agora é exportado para `.sql` antes da execução do Restic, garantindo integridade dos dados de identidade.
- **VPN Observability:** Habilitado servidor de debug no Tailscale (`--debug=0.0.0.0:9002`) para expor métricas internas. Configurado Prometheus para scrap do endpoint `/debug/metrics`.
- **SIEM Leve (Loki + Alloy):**
    - Habilitada ingestão de logs de auditoria do Linux (`/var/log/auth.log`) para rastrear sessões SSH e execução de comandos `sudo`.
    - Habilitada ingestão do `systemd-journal` para logs gerais do sistema e Docker.

### Corrigido (Fixed)
- **Tailscale Config:** Substituída variável depreciada `TS_EXTRA_ARGS` por `TS_TAILSCALED_EXTRA_ARGS` para passar flags corretamente ao daemon na imagem oficial.
- **Alloy Ingestion:**
    - Corrigido erro "File is a directory" criando o arquivo `auth.log` vazio via Ansible antes da montagem do volume.
    - Corrigido erro "Timestamp too old" ajustando `max_age` para `1h`, impedindo o Alloy de tentar processar logs históricos rejeitados pelo Loki.
## [2026-02-01] - Remote Access & VPN Routing
### Adicionado (Added)
- **Tailscale Subnet Router:** Implementado no DockerHost anunciando a rede `10.10.0.0/16`.
- **Systemd NAT Service:** Criado `tailscale-nat.service` para persistência de regras de Masquerading e Forwarding, contornando limitações de roteamento de retorno e bloqueios do Docker.
- **Ansible AuthKey:** Implementada injeção segura de chaves Tailscale via `.env` e `vars_prompt`.

### Alterado (Changed)
- **Vault Firewall:** Atualizada regra UFW na VM Vault para permitir SSH vindo do DockerHost (Jump Server scenario).
- **Tailscale ACLs:** Política refinada para usar origem por e-mail explícito (`src: ["email"]`) em vez de tags ou grupos automáticos, garantindo controle granular sobre quem acessa a rede interna e manter `tag:rpi` restrito ao Dropbear.

## [2026-01-31] - Sovereign Communication Stack
### Adicionado (Added)
- **Nostr Relay:** Implementado servidor `nostr-rs-relay` no DockerHost com persistência SQLite.
- **Tor Hidden Service:** Configurado container Tor sidecar para expor o Relay via rede Onion (`.onion`) isolada.
- **Whitelist Security:** Configuração de restrição de publicação (NIP-01) permitindo escrita apenas para a chave mestre do proprietário.
- **Ansible Automation:** Adicionada task de sincronização (`synchronize`) e deploy do stack Nostr no playbook `manage_stacks.yml`, com tratamento especial para permissões de chaves Tor (`mode 0700`).

### Corrigido (Fixed)
- **Traefik Routing:** Corrigido erro de *Gateway Timeout* em containers multi-rede forçando a rede de proxy via label `traefik.docker.network`.
- **Tor Permissions:** Corrigida falha de boot do Tor ajustando o *ownership* da pasta de chaves para `root` via Ansible.

## [2026-01-30] - Stability & Maintenance
### Corrigido (Fixed)
- **CrowdSec DNS:** Resolvido loop de reinício do container CrowdSec apontando a resolução de DNS para o AdGuard interno (`10.10.30.5`), contornando o bloqueio de saída da VLAN 30.

## [2026-01-29] - Emergency Access Completed
### Adicionado (Added)
- **VPN Out-of-Band:** Implementado Tailscale no Raspberry Pi com roteamento para a rede nativa (`192.168.0.0/24`).
- **ACLs Estritas:** Política de segurança "Zero Trust" no Tailscale, restringindo o acesso apenas à porta 2222 do Proxmox e a minha própria conta.
- **Boot Determinístico:** Configurado IP Estático (`192.168.0.200`) no initramfs do Proxmox para garantir acesso SSH sem DHCP.
- **Client Access:** Provisionadas chaves SSH de emergência para dispositivos móveis (Android/Termux).

### Alterado (Changed)
- **Network Interface:** IP do Dropbear fixado, antes DHCP.

## [2026-01-28] - Observabilidade Fase 2 Completa
### Adicionado (Added)
- **Alerting Pipeline:** Implementado Alertmanager integrado ao Ntfy com autenticação Bearer Token.
- **Alert Rules:** Criadas regras de disparo para indisponibilidade de host, saturação de disco/CPU/RAM e falha de coletores.
- **Proxmox Monitoring:** Implementado `prometheus-pve-exporter` para coleta de métricas granulares de LXCs e VMs.
- **Dashboards as Code:** Adicionado dashboard `proxmox-ve.json` (Baseado no ID 10347) via provisionamento automático.
- **Host Monitoring:** Deploy automático do Node Exporter no Proxmox Host e Vault VM via Ansible.

### Corrigido (Fixed)
- **CrowdSec DNS:** Corrigida falha de resolução de nomes forçando servidores DNS no container, resolvendo a falha de comunicação com a CAPI.
- **Alertmanager Permissions:** Ajustada permissão do arquivo de configuração (`0644`) para evitar *CrashLoopBackOff* por erro de leitura.
- **PVE Exporter Auth:** Contornado bug de biblioteca da imagem Docker migrando de Token Auth para Password Auth.

### Segurança (Security)
- **Firewall Vault:** Regra UFW adicionada para permitir tráfego na porta 9100 estritamente a partir do IP do DockerHost.

## [2026-01-27] - AI Experiment & Cleanup
### Adicionado (Added)
- **Experimental:** Criado playbook `setup_ai_node.yml` e configuração de inventário para stack de Inteligência Artificial Local (Ollama + Open WebUI).

### Removido (Removed)
- **Revert:** Removida toda a infraestrutura de IA (LXC AI-Node e Playbooks) após validação de performance.
    - *Motivo:* A execução de modelos LLM (Command-R, Llama 3.1) em CPU (i5-12400) provou-se inviável para uso interativo devido à alta latência de inferência.

## [2026-01-25] - Security Incident Response & Hardening
### Adicionado (Added)
- **CrowdSec Observability:** Habilitado endpoint Prometheus (`0.0.0.0:6060`) e notificações via Ntfy (tópico `alertas_infra`).
- **Ansible Automation:** Implementados *Handlers* para reinício automático de containers ao detectar mudanças de configuração.
- **Backup Coverage:** Adicionados diretórios `/opt/security` (CrowdSec Data) e `/etc/vault` (AppRole Credentials) à rotina de backup do Restic no DockerHost.

### Alterado (Changed)
- **Vault Integration (Refactor):** Migração do método de injeção de segredos.
    - *Antes:* `ROLE_ID` hardcoded em scripts shell no Git.
    - *Depois:* Scripts genéricos lendo credenciais de arquivos protegidos (`/etc/vault/*.roleid`) injetados pelo Ansible em tempo de deploy.
- **CrowdSec Config:** Ajuste de URL de notificação para rede interna Docker (`http://ntfy:80`) evitando Hairpin NAT e erros de SSL.
- **Hardware Status:** Nobreak NHS Gamer Play em processo de devolução por ser incompatível.

### Corrigido (Fixed)
- **Grafana Provisioning:** Corrigida falha de importação do Dashboard CrowdSec (ID 19010).
    - *Causa:* O JSON utilizava uma variável de input `${DS_PROMETHEUS}` incompatível com o provisionamento automático.
    - *Solução:* Substituição forçada via `sed` pelo UID estático do Prometheus (`dfa44v3b15a80b`), garantindo imutabilidade.

### Segurança (Security)
- **Incident Response:** Rotação completa de credenciais (Ntfy Tokens, Vault RoleIDs e SecretIDs) após detecção de exposição acidental em repositório público.
- **Git Hygiene:** Remoção de scripts contendo segredos do histórico e implementação de templates Jinja2 (`.j2`) sanitizados.
## [2026-01-24] - Security Hardening & UPS
### Adicionado (Added)
- **Security:** Implementação do CrowdSec (LAPI no DockerHost, Bouncer no OPNsense).
- **Power:** Integração do Nobreak NHS Gamer Play 1000VA.
### Corrigido (Fixed)
- **Plugin OPNsense:** Bypass da validação de formulário do plugin `os-crowdsec` para permitir LAPI remota.
- **Authentik Monitoring:** Identificado e corrigido o namespace da coleção para `firix/authentik`.
### Dívida Técnica (Known Issues)
- **CrowdSec / Authentik:** Parser da coleção `firix/authentik` incompatível com Authentik 2025 (Parsed = 0).
- **Mitigação Planejada:** 
  - Ajustar Regex local ou
  - Migrar para parser customizado quando necessário.
## [2026-01-22] - Observability Repair & Dashboard as Code
### Adicionado (Added)
- **Dashboard as Code:** Implementado provisionamento automático de dashboards no Grafana.
    - Criada estrutura de diretórios `grafana/provisioning` e `grafana/dashboards`.
    - Dashboards agora são imutáveis e persistidos como código (JSON) no Git.
- **Traefik Metrics:** Habilitado endpoint de métricas Prometheus na porta 8082.

### Corrigido (Fixed)
- **Loki Crash Loop:** Atualizado arquivo de configuração `local-config.yaml` para sintaxe compatível com Loki v3.6.3.
    - Removido parâmetro depreciado `shared_store`.
    - Adicionado parâmetro obrigatório `delete_request_store` no compactador.
- **Traefik Dashboard:** Corrigida ausência de dados no Grafana vinculando as métricas ao EntryPoint dedicado (`--metrics.prometheus.entryPoint=metrics`).

### Alterado (Changed)
- **Monitoring Stack:** Atualizado `docker-compose.yml` para montar volumes de provisionamento do Grafana.
## [2026-01-19] - DNS High Availability & Forensic Hardening
### Adicionado (Added)
- **DNS Secundário (Edge):** Implementado AdGuard Home no Raspberry Pi (`192.168.0.5`) atuando como failover para o nó principal.
- **Forensic Hardening:** Configurado armazenamento em RAM Disk (`tmpfs`) com permissão estrita (`mode=0700`) para o AdGuard Secundário, garantindo "Zero Footprint" físico.
- **Failover Automático:** Configurado DHCP e Firewall no OPNsense para distribuir ambos os DNS (Primário e Secundário) para as VLANs 20 (Trusted) e 50 (IoT).
- **Playbook `setup_rpi_adguard.yml`:** Automação completa para deploy do AdGuard com sintaxe YAML v0.107+, remoção de logs e blindagem de systemd.

### Corrigido (Fixed)
- **Network Routing:** Corrigido erro crítico de "Destination Host Unreachable" no Arch Linux (VLAN Trusted) adicionando Gateway explícito (`10.10.20.1`) no DHCPv4 do OPNsense.
- **AdGuard Configuration:** Resolvido erro de parser YAML (`cannot unmarshal !!seq into string`) migrando para sintaxe inline (`[ "0.0.0.0" ]`) e definindo `schema_version: 29`.
- **Systemd Loop:** Corrigida falha de boot do serviço AdGuard adicionando dependência `RequiresMountsFor` para aguardar a montagem do `tmpfs`.

### Alterado (Changed)
- **OPNsense Gateway Policy:** Removidos Gateways desnecessários na configuração de DNS System (General Settings), eliminando erros de "Directly Connected Network".
## [2026-01-18] - RPi Hardening & Distributed Metrics
### Adicionado (Added)
- **Playbook `hardening_rpi.yml`:** Automação de segurança específica para o Raspberry Pi (Edge), focada em SSH, Fail2Ban e Node Exporter, sem dependências de Docker.
- **Inventory:** Grupo `[rpi]` adicionado ao `hosts.ini` para gestão centralizada.
- **Observability:** Novo target `rpi-edge` adicionado ao `prometheus.yml` para monitoramento de infraestrutura do nó de gerenciamento.

### Alterado (Changed)
- **Prometheus Config:** Atualizada lista de *scrape configs* para incluir endpoints fora da rede Docker (LAN Física).
## [2026-01-17] - UPS Protocol Analysis & RPi Stabilization
### Adicionado (Added)
- **RPi Storage Quirk:** Implementado parâmetro de kernel `usb-storage.quirks` para mitigar falhas do controlador JMicron UAS, estabilizando o boot do SSD via USB 3.0.
- **RPi RTC:** Configurado módulo DS3231 no Debian 13 (Trixie) utilizando Device Tree Overlays e removendo o `fake-hwclock`.

### Alterado (Changed)
- **RPi Network:** Migração da configuração de rede estática para `nmcli` (NetworkManager), alinhando com o padrão do OS moderno.

### Removido (Removed)
- **UPS Integration:** Removidas configurações e drivers do NUT para o Ragtech M2 após confirmação de incompatibilidade de protocolo (Lock-in proprietário). Equipamento marcado para devolução.
## [2026-01-15] - Hardware Provisioning & Power Safety
### Adicionado (Added)
- **Tooling:** Adicionado `rpi-imager` à lista de ferramentas de administração no Arch Linux.
- **Hardware Spec:** Definida fonte **CanaKit 3.5A** como padrão para o Raspberry Pi 4 para suportar SSDs NVMe/SATA via USB sem *undervoltage*.

### Alterado (Changed)
- **Security Policy:** Removido requisito de LUKS (Split Storage) para o nó de gerenciamento (Raspberry Pi) para evitar complicações.
- **Hardware Status:** Nobreak Ragtech colocado em ciclo de carga inicial (24h) antes da conexão de cargas críticas.

### Removido (Removed)
- **Hardware:** Fonte Genérica "U1002" removida do inventário por incompatibilidade física e técnica.
## [2026-01-14] - Observability Phase 1 & PKI Overhaul
### Adicionado (Added)
- **Monitoring Stack:** Implementado Prometheus, Loki, Grafana, Alloy e Ntfy no DockerHost.
- **SECURITY:** Implementada CA Local confiável para domínios `*.home` (Mkcert), substituindo certificados padrão do Traefik e habilitando suporte a Android.
- **Ansible Hardening:** Adicionado `rsync` às dependências e `vars_prompt` para entrada segura de senhas.
- **Backup:** Incluído diretório `/opt/monitoring` na política de backup do Restic.

### Corrigido (Fixed)
- **Traefik Routing:** Resolvido erro 504 Gateway Timeout no Ntfy forçando a rede `proxy` e porta `80` via labels explícitas.
- **Ansible Scope:** Corrigido bug onde o playbook tentava configurar Docker na VM Vault (que não possui Docker).
- **Log Driver:** Alterado driver do Docker para `json-file` para permitir ingestão de logs pelo Alloy sem latência de socket.
## [2026-01-11] - Host Hardening & Defense in Depth
### Adicionado (Added)
- **Proxmox Hardening:** Criado playbook `hardening_proxmox.yml` dedicado ao Host Físico, implementando Fail2Ban para a interface web (porta 8006) e proteção SSH.
- **Fail2Ban (Debian):** Implementada configuração agressiva (`mode = aggressive`) com backend `systemd` e whitelist de IPs confiáveis (Management + Trusted Network) para evitar lockout.

### Alterado (Changed)
- **SSH Policy:** Substituído parâmetro legado `ChallengeResponseAuthentication` por `KbdInteractiveAuthentication` no Debian 12+, eliminando warnings de depreciação.
- **Update Strategy:** Alterada estratégia de atualização automática do Ansible de `dist-upgrade` para `safe-upgrade` em servidores Debian, mitigando risco de quebra de dependências críticas (ex: Docker/ZFS).
## [2026-01-10] - Security & DNS Tuning
### Alterado (Changed)
- **Credential Policy:** Executada rotação global de senhas para padrões de alta complexidade em toda a infraestrutura (Host, VMs, LXCs, Apps), eliminando senhas fracas e repetitíveis.
- **AdGuard Configuration:** Otimizado para performance (Parallel Requests, Optimistic Cache, DNSSEC) e ampliada a cobertura de bloqueio com a lista `OISD Big`.
- **Backblaze Lifecycle:** Alterada política do bucket para "Keep only the last version" para compatibilidade correta com o garbage collection (`prune`) do Restic e prevenção de custos excessivos.

### Corrigido (Fixed)
- **Alpine SSH:** Corrigido playbook `hardening_alpine.yml` para garantir que o serviço `sshd` seja explicitamente habilitado e iniciado no boot, resolvendo falha de conexão ("Connection Refused") em novos containers.
## [2026-01-09] - Backup Strategy & GitOps
### Adicionado (Added)
- **Restic Backup:** Implementada solução de backup criptografado (Client-side) para Backblaze B2 em todos os hosts (DockerHost, Vault, AdGuard, Management).
- **Vault Snapshot:** Script de automação para snapshot do banco Raft antes do backup, com rotação automática de tokens.
- **OPNsense Schedules:** Implementado agendamento de firewall `HorarioBackupVault` (03:59-04:30) para permitir backup do Vault mantendo isolamento no resto do dia.
- **OPNsense Git Backup:** Configurado plugin para versionamento automático da configuração do firewall.
- **Hardening Playbooks:** Adicionado suporte a Alpine Linux (`hardening_alpine.yml`) e corrigida política de SSH para evitar lockout (`prohibit-password`).
- **Timezone Standardization:** Integrado ajuste automático de fuso horário (`America/Sao_Paulo`) nos playbooks de hardening para garantir consistência de logs e agendamentos entre Alpine e Debian.

### Alterado (Changed)
- **Infrastructure Management:** Migração completa do DockerHost para modelo GitOps. Configurações manuais foram importadas para o Git e agora são aplicadas via Ansible (`manage_stacks.yml`).
- **Security Policy:** Refinado hardening SSH para permitir automação via Ansible (Root via Key Only) em conformidade com Debian e Alpine.
## [2026-01-08] - GitOps Migration
### Adicionado (Added)
- **Playbook `manage_stacks.yml`:** Automação centralizada para deploy e manutenção de stacks Docker.
- **Config Import:** Importadas configurações de produção (Traefik, Authentik, Vaultwarden) para o controle de versão.

### Alterado (Changed)
- **Deployment Strategy:** Substituída a gestão manual (`docker compose up`) por gestão via Ansible + Systemd para serviços críticos, garantindo reinício automático e integração com Vault.
## [2026-01-07] - Automation Foundation
### Adicionado (Added)
- **VLAN 10 (MGMT):** Rede dedicada para gerenciamento de infraestrutura (`10.10.10.0/24`) implementada no OPNsense e Proxmox.
- **LXC Management (ID 102):** Container Alpine Linux configurado como controlador central (Ansible/Terraform).
    - *Network:* Static IP `10.10.10.10`, Tag VLAN 10.
    - *Security:* Firewall Proxmox ativado, isolado na rede de gestão.
- **Ansible Setup:**
    - Configurado `ansible.cfg` com defaults seguros e inventário automático.
    - Criado Playbook `hardening_debian.yml` para padronização de segurança em servidores Debian.
- **DockerHost Prep:** Instalado pacote `sudo` e configuradas permissões de elevação sem senha para o usuário operacional, permitindo automação remota.

### Corrigido (Fixed)
- **VLAN Filtering:** Corrigida configuração da VM OPNsense no Proxmox que descartava silenciosamente pacotes da VLAN 10 na interface trunk (`net1`).
## [2026-01-05] - Disaster Recovery Drill
### Adicionado (Added)
- **Policy RBAC:** Restaurada política de acesso `Require Infra Admin` (Python) para proteger dashboards administrativos após perda de banco de dados.
- **Vaultwarden:** Implementado gerenciador de senhas self-hosted.
    - *Backend:* SQLite (Single-file).
    - *Segurança:* Integração AppRole para injeção de `ADMIN_TOKEN`.
    - *Roteamento:* Rota `/admin` protegida por Authentik; API aberta para clientes móveis.

### Validado (Verified)
- **Cold Boot Resilience:** Confirmado que a infraestrutura recupera-se automaticamente após o desbloqueio manual do Vault, validando o script de retry do Systemd (`authentik-vault`).
## [2026-01-04] - Phase 2 Completion (Identity & Secrets)
### Adicionado (Added)
- **Vault AppRole:** Implementada autenticação automatizada Machine-to-Machine para o DockerHost.
    - Criada Policy `docker-host-ro` (Leitura estrita em `kv/data/*`).
    - Credenciais de robô (`SecretID`) armazenadas em arquivo protegido (`/etc/vault/` com permissão 600).
- **DNS Persistente:** Configurado `systemd-resolved` no DockerHost para utilizar o AdGuard (`10.10.30.5`) de forma definitiva, eliminando dependência de `/etc/hosts`.
- **Automação de Boot (Systemd):** Criado serviço `authentik-vault.service`.
    - *Função:* Busca a senha do banco no Vault via script (`start-with-vault.sh`) e injeta na memória RAM antes de iniciar o Docker Compose.
    - *Resiliência:* Configurado com `Restart=on-failure` para aguardar o desbloqueio (Unseal) do Vault após quedas de energia.

### Alterado (Changed)
- **Authentik Hardening:** Removida a senha do banco de dados (`POSTGRES_PASSWORD`) do arquivo `.env` e `docker-compose.yml`. A senha agora existe apenas na memória RAM durante a execução.
## [2026-01-04] - Vault Architecture Refactor
### Adicionado (Added)
- **VLAN 40 (SECURE):** Implementada rede isolada no OPNsense para ativos de alta criticidade.
- **VM Vault (ID 106):** Provisionada VM dedicada (Debian 13 Minimal) para hospedar o HashiCorp Vault, substituindo o container anterior.

### Alterado (Changed)
- **Vault Migration:** Migrado serviço HashiCorp Vault de DockerHost para VM Dedicada.
    - *Network Flow:* Traefik (VLAN 30) -> Firewall (Passagem TCP/8200 Estrita) -> Vault VM (VLAN 40).
- **Hardening de Host (Vault):**
    - Implementado **UFW** com política *Default Deny*. Acesso SSH restrito a VLANs de gestão e API restrita ao DockerHost.
    - **Isolamento Total:** Bloqueio de saída para internet aplicado no OPNsense (VLAN 40).
- **Traefik Configuration:** Habilitado `file provider` (`--providers.file`) para gerenciar roteamento para serviços externos (Non-Docker).
## [2026-01-03] - Secret Management
### Adicionado (Added)
- **HashiCorp Vault (Secrets Manager):** Implantado Vault v1.21.1 (Stable) com storage Raft integrado.
    - *Segurança:* Inicializado manualmente (Shamir's Secret Sharing 3/5).
    - *Integração:* Exposto via Traefik (`vault.home`) e protegido por autenticação MFA/SSO via Authentik (Middleware ForwardAuth).
    - *Fix de UI:* Configurado `api_addr` para `https://vault.home` para prevenir loops de redirecionamento locais.
## [2026-01-02] - Ingress Controller V3
### Adicionado (Added)
- **Authentik (IdP):** Implantado stack completa de identidade (v2025.10.3) com PostgreSQL 16 e Redis 7.
    - *ForwardAuth:* Configurado middleware global `authentik@docker` no Traefik.
    - *Zero Trust:* Traefik Dashboard (`traefik.home`) agora exige autenticação centralizada, eliminando acesso direto inseguro.
    - *Global Callback:* Implementada rota de roteamento `PathPrefix(/outpost.goauthentik.io/)` no Traefik para garantir o retorno de fluxos OAuth em qualquer subdomínio protegido.
- **Socket Proxy:** Implementado `tecnativa/docker-socket-proxy` para mediar a comunicação entre o Traefik e o Docker Daemon, revogando acesso root direto ao socket.
- **Log Rotation:** Configurado driver `json-file` com limite de 30MB (3x10MB) por container para prevenir exaustão de disco.
- **Unattended Upgrades:** Ativadas atualizações automáticas de segurança no Debian 13.
- **Traefik v3.6:** Atualizado Ingress Controller para a versão estável mais recente.
    - *Compatibility Fix:* Implementada variável de ambiente `DOCKER_API_VERSION=1.45` para contornar falha de negociação de API no Debian 13 (Trixie).
- **Authentik Stack:** Implantado Sistema de Gestão de Identidade (IdP) versão `2025.10.3`.
    - *Componentes:* Server, Worker, PostgreSQL 16 e Redis 7.
    - *Segurança:* Rodando como usuário não-privilegiado (UID 1000), sem acesso ao Docker Socket.
    - *Ingress:* Exposto via Traefik em `https://auth.home`.
    - *Middleware:* Configurado `authentik@docker` no Traefik para proteger futuras aplicações (Forward Auth).
- *RBAC:* Implementada política de acesso baseada em grupo (`infra-admins`) usando expressão Python no Authentik para restringir o acesso a dashboards administrativos.

### Removido (Removed)
- **Traefik v2.11:** Descontinuado uso da versão legado após validação do fix na v3.

### Alterado (Changed)
- **Filesystem Standard:** Padronizada estrutura de diretórios em `/opt/{traefik,services,auth,monitoring}` com permissões para o usuário não-root (`fajre`).
- **Traefik Routing:** Corrigida falha de loop de redirecionamento (404) durante o callback de autenticação, adicionando regra explícita para o Outpost Embutido.
## [2025-12-31] - Ingress Controller
### Adicionado (Added)
- **Traefik v2.11:** Implantado como Proxy Reverso na porta 80/443 do DockerHost.
    - *Configuração:* Dashboard na porta 8080 (LAN), Redirecionamento HTTP->HTTPS Global.
- **DNS Rewrite:** Configurado `*.home` no AdGuard apontando para o DockerHost (`10.10.30.10`).

### Corrigido (Fixed)
- **Docker API Mismatch:** Resolvido erro "client version 1.24 is too old" no Debian 13 forçando `DOCKER_API_VERSION=1.45` nas variáveis de ambiente do container Traefik.
## [2025-12-30] - DNS Local e AdBlocking
### Adicionado (Added)
- **AdGuard Home:** Implantado servidor DNS local (LXC ID 101) para filtragem de conteúdo e privacidade.
    - *Features:* DNS-over-HTTPS upstream e resolução reversa local.

### Alterado (Changed)
- **DHCP Configuration:** Migrados clientes das VLANs TRUSTED e IOT para utilizarem exclusivamente o DNS Local (`10.10.30.5`), garantindo bloqueio de anúncios em toda a rede.
- Documentação do repo melhor documentada e formatada.
- Repo aberto.
## [2025-12-29] - DockerHost Hardening
### Adicionado (Added)
- **Docker Engine:** Instalado Docker CE e Docker Compose v5 no DockerHost (VM 105).
- **SSH Keys:** Implementada autenticação exclusiva por chave pública (Ed25519) no DockerHost.

### Corrigido (Fixed)
- **Firewall Policy:** Corrigida falta de regra de roteamento Inter-VLAN que impedia a rede TRUSTED de acessar a rede SERVER via SSH/ICMP. O mesmo feito com a VLAN 50 (IOT).

### Alterado (Changed)
- **SSH Config:** Desabilitada autenticação por senha e login de root no DockerHost para compliance com a política de segurança.
## [2025-12-28] - Correção de Driver OPNsense
### Corrigido (Fixed)
- **VLAN Interface Loss:** Resolvido desaparecimento das interfaces VLAN (Trusted/Server/IoT) causado pela migração de driver `e1000` > `VirtIO`.
    - Realizado re-mapeamento (re-parenting) das VLANs para a interface `vtnet1` (Trunk) e reconfiguração dos endereços IP estáticos.
## [2025-12-27] - Provisionamento DockerHost
### Adicionado (Added)
- **VLAN 30 (SERVER):** Rede isolada para servidores de aplicação configurada no OPNsense.
- **VM DockerHost:** Instância Debian (ID 105) implantada na VLAN 30 para hospedar containers.
    - *Specs:* 2 vCPU, 8GB RAM, 32GB Storage (IO Thread enabled).
## [2025-12-26] - Correção de Infraestrutura de Rede
### Corrigido (Fixed)
- **Routing Loop:** Resolvido conflito crítico de roteamento onde LAN e WAN compartilhavam a sub-rede `192.168.0.x`. LAN migrada para `192.168.99.0/24`.
- **Proxmox VLAN Tagging:** Corrigida a bridge `vmbr0` descartando pacotes taggeados. Adicionado parâmetro `bridge-vids 2-4094` para permitir tráfego de VLANs na bridge.
- **OPNsense VirtIO:** Desativado *Hardware Checksum Offloading* (CRC/TSO/LRO) para corrigir falhas de DHCP e integridade de pacotes em ambiente virtualizado.
- **Firewall Rules:** Implementadas regras de saída (Pass All) e NAT Híbrido para as VLANs IOT (50) e TRUSTED (20).

### Adicionado (Added)
- **Troubleshooting Guide:** Adicionados comandos de diagnóstico de rede (tcpdump, bridge vlan) ao `maintenance.md`.
## [2025-12-25] - Upgrade de Storage Bitcoin
### Alterado (Changed)
- **Hardware de Storage:** Substituído SSD planejado (SanDisk Plus 2TB) por Samsung 870 EVO 2TB.
    - *Motivo Técnico:* O modelo anterior era DRAM-less, o que causaria degradação severa de performance (IOPS) durante a sincronização inicial (IBD) do Bitcoin Node.
    - *Motivo Logístico:* Falha e demora de entrega do antigo e abaixo do preço.
## [2025-12-24] - Correção de Boot e Rede
### Corrigido (Fixed)
- **Boot Network:** Removida configuração de IP Estático hardcoded (`IP:10.10.10.1...`) do `initramfs.conf` que causava conflitos de rede ao mudar a topologia. Alterado para `IP=dhcp`.
- **Remote Unlock:** Corrigida falha de autenticação no Dropbear SSH e permissões de chave (`chmod 600 authorized_keys`).
- **Network Interface:** Normalizada nomenclatura da interface física para `nic0` (renomeada de `enp4s0` via udev/systemd) e revertida configuração da bridge `vmbr0` para DHCP para facilitar manutenção.

### Revertido (Reverted)
- **Switch Configuration:** Reset físico do Switch TP-Link para "Factory Defaults" (Layer 2 Flat), desfazendo a segmentação de VLANs temporariamente para recuperar o acesso ao servidor.

## [2025-12-22] - Migração Router-on-a-Stick e Otimização de Hardware
### Adicionado (Added)
- **VLAN Trunking:** Implementada VLAN 90 (WAN_FIBRA) no Proxmox e OPNsense via interface onboard.
- **Router-on-a-Stick:** Configuração funcional utilizando o Switch TP-Link para multiplexação de tráfego WAN/LAN em um único cabo físico.

### Alterado (Changed)
- **Dropbear:** Reconfigurado para escutar na porta `2222` e utilizar a interface `enp4s0` (onboard) após a remoção da placa PCIe.
- **Topology:** Transição de rede física multiserial para topologia virtualizada baseada em VLANs (802.1Q).

### Removido (Removed)
- **Hardware PCIe:** Placa HP Quad-Port removida devido a incompatibilidade de drivers/conflito IRQ e redundância técnica após implementação de VLANs.

## [2025-12-22] - Migração Router-on-a-Stick e Otimização de Hardware
### Adicionado (Added)
- **VLAN Trunking:** Implementada VLAN 90 (WAN_FIBRA) no Proxmox e OPNsense via interface onboard.
- **Router-on-a-Stick:** Configuração funcional utilizando o Switch TP-Link para multiplexação de tráfego WAN/LAN em um único cabo físico.

### Alterado (Changed)
- **Dropbear:** Reconfigurado para escutar na porta `2222` e utilizar a interface `enp4s0` (onboard) após a remoção da placa PCIe.
- **Topology:** Transição de rede física multiserial para topologia virtualizada baseada em VLANs (802.1Q).

### Removido (Removed)
- **Hardware PCIe:** Placa HP Quad-Port removida devido a incompatibilidade de drivers/conflito IRQ e redundância técnica após implementação de VLANs.

## [2025-12-21] - Hardening e Acesso Remoto
### Adicionado (Added)
- **ZFS Swap:** Configurada partição de swap de 16GB em ZVOL para mitigar OOM (Out of Memory) e deadlocks no ZFS.
- **Dropbear SSH:** Implementado servidor SSH leve no initramfs para permitir desbloqueio remoto de disco (Headless Boot).
- **FDE (Full Disk Encryption):** Conversão do sistema de arquivos raiz (Root FS) para LUKS2 (AES-XTS-Plain64) com chave de 512 bits.

---

## [2025-12-20] - Inicialização do Sistema
### Adicionado (Added)
- **OS Base:** Instalação limpa do Proxmox VE 9.1.
- **Storage:** Criação do pool `rpool` em ZFS Mirror (RAID1) nos SSDs NVMe.

### Corrigido (Fixed)
- **Conectividade:** Ajuste de regras de firewall no client (Arch Linux) para permitir comunicação ICMP/SSH em conexão direta (sem roteador).

---

## [2025-12-19] - Validação de Hardware
### Adicionado (Added)
- **Burn-in Test:** Validação de memória RAM (MemTest86) concluída com 0 erros (Duração: 6h 17m).
- **Evidência:** Adicionado screenshot do resultado do MemTest86 em `docs/assets/benchmarks/MemTest86.jpeg`.

### Alterado (Changed)
- **BIOS:** Configurações críticas aplicadas para virtualização:
    - `VT-d` e `Virtualization Tech` habilitados.
    - `AC BACK` definido para "Always On".
    - `Secure Boot` e `CSM` desabilitados para compatibilidade com ZFS/LUKS customizado.
