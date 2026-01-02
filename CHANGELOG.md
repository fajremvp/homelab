# Changelog

Todas as mudanças notáveis serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e este projeto adere ao versionamento semântico (onde aplicável).

## [Unreleased]
### Planejado
- Traefik (Reverse proxy)

---
## [2026-01-02] - Ingress Controller V3
### Adicionado (Added)
- **Socket Proxy:** Implementado `tecnativa/docker-socket-proxy` para mediar a comunicação entre o Traefik e o Docker Daemon, revogando acesso root direto ao socket.
- **Log Rotation:** Configurado driver `json-file` com limite de 30MB (3x10MB) por container para prevenir exaustão de disco.
- **Unattended Upgrades:** Ativadas atualizações automáticas de segurança no Debian 13.
- **Traefik v3.6:** Atualizado Ingress Controller para a versão estável mais recente.
    - *Compatibility Fix:* Implementada variável de ambiente `DOCKER_API_VERSION=1.45` para contornar falha de negociação de API no Debian 13 (Trixie).

### Removido (Removed)
- **Traefik v2.11:** Descontinuado uso da versão legado após validação do fix na v3.

### Alterado (Changed)
- **Filesystem Standard:** Padronizada estrutura de diretórios em `/opt/{traefik,services,auth,monitoring}` com permissões para o usuário não-root (`fajre`).
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
