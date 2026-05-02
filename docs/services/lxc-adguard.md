// Melhorar essa documentação

* **AdGuard Home e Unbound (DNS):**
    * **Estratégia de DHCP (Failover Automático):**
      - **VLAN TRUSTED/IOT (Clientes):** O OPNsense entregará via DHCP **dois endereços IP** de DNS para garantir alta disponibilidade:
        1. **Primário:** IP do LXC AdGuard (Proxmox).
        2. **Secundário:** IP do Raspberry Pi.
        - *Comportamento:* Os clientes alternam automaticamente para o Pi caso o servidor principal não responda, garantindo navegação ininterrupta e bloqueio de anúncios contínuo.
      - **VLANs SERVER, MGMT e SECURE (Infraestrutura):** Recebem **apenas** o IP do respectivo Gateway (OPNsense). O uso de DNS externos (`1.1.1.1` ou `8.8.8.8`) é **PROIBIDO**.
        - *Justificativa Dupla:* 1. Garante que servidores nunca percam conectividade DNS mesmo se os containers do AdGuard falharem (Evita dependência cíclica).
          2. Mantém a Soberania Total de Dados: A infraestrutura consulta o Unbound, que vai direto nos Root Servers, eliminando rastreamento corporativo.
      - **Pipeline de Resolução (Security Funnel):**
        * Os AdGuards **não usam Cloudflare ou Quad9**. Seu único upstream é o Unbound do OPNsense.
      - **Definição dos Nós DNS:**
        * **Primário:** `[LXC Alpine]` - No servidor principal. Serviço leve. Ter um IP dedicado (via LXC) facilita apontar o OPNsense para ele.
        * **Secundário:** `[Raspberry Pi]` - Instância de backup rodando no Pi de gerenciamento.
    * **Estratégia Anti-Loop:** O OPNsense (Router) usará seu próprio **Unbound nativo** (localhost) para resolver nomes de infraestrutura, garantindo que ele nunca dependa do AdGuard para bootar. O AdGuard será entregue apenas aos clientes (PCs/Celulares) via DHCP.
    * **Exceções e Whitelists Globais:** Para garantir o funcionamento pleno da stack de infraestrutura, as seguintes exceções foram aplicadas diretamente nas **Custom Rules** do AdGuard:
        * **Speedtest Tracker (Pre-Check):** `@@||icanhazip.com^`
            * **Justificativa:** Antes de inicializar as threads de teste do Ookla CLI, a aplicação faz um ICMP/GET para `icanhazip.com` para descobrir o IP WAN e atestar a existência de conectividade externa. Sem essa whitelist, algumas listas agressivas do AdGuard bloqueiam o domínio, fazendo o teste falhar precocemente com o status "Checking failed".

### Relacionados/Ligados ao AdGuard (melhor explicado em network-stack.md):

    * Traefik - Split-Horizon

## Backup e Persistência
Implementado em: 2026-01-09.

Apesar de ser um serviço leve, o AdGuard possui configurações de bloqueio e logs importantes.
* **Backup Automático:** Restic (Diário às 04:30).
* **Alvo:** Diretório `/opt/AdGuardHome` (Inclui binário, `AdGuardHome.yaml` e banco de dados de estatísticas).
* **Restauro:** Em caso de falha, basta reinstalar o container Alpine base e rodar `restic restore`.
