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

O OPNsense atua exclusivamente como executor (Músculo), consultando o Agente (LAPI) rodando no DockerHost.

### Configuração do Plugin (Workaround & Settings)
O plugin `os-crowdsec` possui uma validação de formulário restritiva na UI. Para configurá-lo como "Bouncer Only":

1. **Interface Web (Services > CrowdSec):**
    * `Enable Log Processor (IDS)`: **[ ] Desmarcado** (Economia de CPU/RAM, logs são processados no DockerHost).
    * `Enable LAPI`: **[ ] Desmarcado** (Não rodar servidor no Firewall).
    * `Enable Remediation (IPS)`: **[x] Marcado** (Ativa o bloqueio).
    * `Create blocklist rules`: **[x] Marcado** (Cria regras flutuantes automaticamente).
    * **Truque de Validação:** Preencher `LAPI listen address` com `127.0.0.1` apenas para permitir o botão "Apply" (o serviço ignorará isso pois a LAPI local está desativada).

2. **Conexão Real (Via SSH):**
    Devido à limitação da UI, a conexão real deve ser editada manualmente no arquivo `/usr/local/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`:
    ```yaml
    api_key: 'CHAVE_GERADA_NO_DOCKERHOST_CSCLI'
    api_url: http://10.10.30.10:8080/
    ```

3. **Validação:**
    * **Firewall > Rules > Floating:** Deve existir uma regra gerada automaticamente (geralmente cinza) bloqueando a lista negra do CrowdSec.

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
