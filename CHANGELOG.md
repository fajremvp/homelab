# Changelog

Todas as mudanças notáveis serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto adere ao versionamento semântico (onde aplicável).

## [Unreleased]
### Planejado

- Organizar cabos
- Fazer uma bancadinha/rack pra deixar tudo
- Encontrar um novo Nobreak

---
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
- **Evidência:** Adicionado screenshot do resultado do MemTest86 em `docs/assets/benchmarks/`.

### Alterado (Changed)
- **BIOS:** Configurações críticas aplicadas para virtualização:
    - `VT-d` e `Virtualization Tech` habilitados.
    - `AC BACK` definido para "Always On".
    - `Secure Boot` e `CSM` desabilitados para compatibilidade com ZFS/LUKS customizado.
