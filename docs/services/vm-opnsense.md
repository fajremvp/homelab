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
