* **OPNsense (Firewall):** `[VM Dedicada - VirtIO Bridge]`
    * **Justificativa:** Roteador principal da rede. Utiliza placas de rede virtuais (VirtIO) ligadas às Bridges físicas do Proxmox. Isso permite que o Host e a VM compartilhem a conexão física sem hardware extra.
    * **Ingress:** Configurado com **NAT Port Forwarding** puro (Portas 80/443 WAN -> IP do Traefik). O SSL é terminado no Traefik.

### Relacionados/Ligados ao OPNsense (melhor explicado em network-stack.md):

    * VPN 1 - Traffic Shaping (QoS)
    * VPN 2 - Privacidade (Outbound - Cliente WireGuard)
    * Tor (Gateway/Proxy)
    * AdGuard Home e Unbound (DNS) - várias configs
    * HashiCorp Vault (Firewall)
    * CrowdSec - Bouncer ("Músculo")

## CrowdSec Bouncer (Remediation)
Implementação realizada em: 2026-01-24.

O OPNsense atua como o executor (Músculo) das decisões do Agente.

* **Plugin:** `os-crowdsec` (apenas componente IPS/Remediation ativo).
* **Configuração via SSH:** Devido a limitações da interface, o arquivo `/usr/local/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` foi editado manualmente para apontar para o LAPI externo (`10.10.30.10:8080`).
* **Regras de Firewall:**
    - **Floating Rule:** O plugin cria automaticamente regras flutuantes que consultam a tabela `crowdsec_blocklists`, bloqueando ataques em todas as interfaces simultaneamente.

## Estratégia de Backup e Agendamento
Implementado em: 2026-01-09.

### 1. Versionamento de Configuração (Git)
O plugin `os-git-backup` monitora alterações no `config.xml`.
* **Trigger:** Evento de "Save" na interface web.
* **Destino:** Repositório Privado no GitHub.
* **Segurança:** Utiliza chave SSH RSA dedicada. O XML é criptografado nativamente pelo OPNsense antes do upload.

### 2. Controle de Acesso Temporal (Vault Backup)
Para permitir que o **Vault (VLAN 40)** faça backup no Backblaze sem expô-lo à internet o dia todo:
* **Feature:** OPNsense Schedules.
* **Schedule:** `HorarioBackupVault` (03:59 - 04:30 Diariamente).
* **Regra de Firewall:**
    * **Action:** Pass
    * **Source:** Vault Net
    * **Destination:** Any (Internet)
    * **Schedule:** `HorarioBackupVault`
* **Resultado:** O Vault permanece isolado (Air-gapped) por 23h30m/dia, abrindo a janela apenas para o Restic operar.
