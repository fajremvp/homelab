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
    * **Regras Personalizadas Globais (Custom Rules):** Para garantir o funcionamento da infraestrutura e blindar a rede contra vazamentos de privacidade específicos, as seguintes regras manuais foram aplicadas no AdGuard:
        * **Bloqueios Direcionados (Blacklist):**
            * `||samsungads.com^`
            * `||samsungacr.com^`
            * `||log-config.samsungacr.com^`
                * **Justificativa:** Bloqueio agressivo de telemetria, anúncios nativos e ACR (*Automatic Content Recognition*) embutidos no sistema operacional de Smart TVs e celulares da Samsung.
            * `||slither.io^`
                * **Justificativa:** Bloqueio pontual manual (distrações/jogos de navegador).
        * **Exceções (Whitelist):**
            * **Speedtest Tracker (Pre-Check):** `@@||icanhazip.com^`
                * **Justificativa:** Antes de inicializar as threads de teste do Ookla CLI, a aplicação faz um ICMP/GET para `icanhazip.com` para descobrir o IP WAN e atestar a existência de conectividade externa. Sem essa whitelist, listas agressivas do AdGuard bloqueiam o domínio, fazendo o teste falhar precocemente com o status "Checking failed".

### Relacionados/Ligados ao AdGuard (melhor explicado em network-stack.md):

    * Traefik - Split-Horizon

## Backup e Persistência
Implementado em: 2026-01-09.

Apesar de ser um serviço leve, o AdGuard possui configurações de bloqueio e logs importantes.
* **Backup Automático:** Restic (Diário às 04:30).
* **Alvo:** Diretório `/opt/AdGuardHome` (Inclui binário, `AdGuardHome.yaml` e banco de dados de estatísticas).
* **Restauro:** Em caso de falha, basta reinstalar o container Alpine base e rodar `restic restore`.
