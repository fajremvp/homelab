// Melhorar essa documentação

* **AdGuard Home e Unbound (DNS):**
    * **Estratégia de DHCP (Failover Automático):**
      - **VLAN TRUSTED/IOT (Clientes):** O OPNsense entregará via DHCP **dois endereços IP** de DNS para garantir alta disponibilidade:
        1. **Primário:** IP do LXC AdGuard (Proxmox).
        2. **Secundário:** IP do Raspberry Pi.
        - *Comportamento:* Os clientes alternam automaticamente para o Pi caso o servidor principal não responda (timeout), garantindo navegação ininterrupta durante manutenções sem intervenção do usuário.
      - **VLAN SERVER (Infraestrutura):** Recebem apenas o IP do **Gateway (OPNsense) ou 1.1.1.1**.
        - *Justificativa:* Garante que servidores nunca percam conectividade DNS (updates/NTP) mesmo se o container do AdGuard falhar ou estiver em loop de boot, evitando dependência cíclica.
      - **Definição dos Nós DNS:**
        * **Primário:** `[LXC Alpine]` - No servidor principal. Serviço leve. Ter um IP dedicado (via LXC) facilita apontar o OPNsense para ele.
        * **Secundário:** `[Raspberry Pi]` - Instância de backup rodando no Pi de gerenciamento.
    * **Estratégia Anti-Loop:** O OPNsense (Router) usará seu próprio **Unbound nativo** (localhost) para resolver nomes de infraestrutura, garantindo que ele nunca dependa do AdGuard para bootar. O AdGuard será entregue apenas aos clientes (PCs/Celulares) via DHCP.

### Relacionados/Ligados ao AdGuard (melhor explicado em network-stack.md):

    * Traefik - Split-Horizon
