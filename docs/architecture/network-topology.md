### 3. Topologia de Rede e Segmentação (VLANs)

* **Estratégia:** Segmentação física e lógica rigorosa (Micro-segmentação). O OPNsense atua como gateway único e firewall entre essas zonas. Todo tráfego inter-VLAN é negado por padrão ("Default Deny") e liberado apenas estritamente via regras de firewall.

| VLAN ID | Nome | CIDR | Descrição / Quem habita |
| :--- | :--- | :--- | :--- |
| **90** | `WAN_FIBRA` (Internet) | `192.168.0.x` (DHCP) | **Tráfego Externo**. Rede do modem da operadora. Entra via Porta 8 do Switch ou direta e é entregue ao OPNsense. |
| **1** | `LAN_ADMIN` (Physical) | `192.168.99.0/24` | **"Acesso de Administração"**. Rede física padrão do OPNsense (migrada de 192.168.0.x para evitar conflito de rota com a WAN). Usada como porta de emergência caso as VLANs falhem. |
| **10** | `MGMT` (Management) | `10.10.10.0/24` | **"A Torre de Controle"**. Acesso restrito. **Regra de Ouro:** IPs Estáticos obrigatórios para Proxmox e Pi. Não dependem de DHCP. **Porta de Emergência:** Uma porta física do switch será configurada como "Untagged VLAN 10". **Etiqueta Física** (Protocolo de Crise): Colar uma etiqueta física no switch ou no case do servidor contendo: "IP Emergência: 10.10.10.99 / Máscara: 255.255.255.0 / GW: 10.10.10.1". Garante acesso rápido via notebook mesmo em pânico ou sem memória. |
| **20** | `TRUSTED` (Home) | `10.10.20.0/24` | **"Dispositivos Pessoais"**. Rede de confiança média-alta. Habitantes: Notebook Arch, Celular, Desktop. Acesso permitido à Internet e, via regras restritas, a serviços na VLAN SERVER. |
| **30** | `SERVER` (Services) | `10.10.30.0/24` | **"Produção"**. Onde rodam os serviços estáveis. Habitantes: DockerHost (Stalwart, Nostr, Vaultwarden, Forgejo), Bitcoin Node. Isolados, acessíveis apenas via portas específicas (ex: 443 via Traefik). |
| **40** | `SECURE` (High Security) | `10.10.40.0/24` | **"O Cofre"**. Isolamento máximo. Sem acesso direto à internet (exceto update controlado). Habitantes: HashiCorp Vault. |
| **50** | `IOT` (Untrusted) | `10.10.50.0/24` | **"A Selva"**. Dispositivos que não controlo e não confio. Sem acesso à VLAN de gerenciamento ou servidores. Habitantes: TV Smart, Lâmpadas, Impressora, Visitantes (Guest Wi-Fi). |
| **60** | `LAB` (K8s/Dev) | `10.10.60.0/24` | **"O Caos Controlado"**. Ambiente efêmero para testes e quebras. Habitantes: Cluster Kubernetes, VMs de teste. Se for comprometido, não afeta a Produção. |
| **99** | `DMZ/DANGER` | `10.10.99.0/24` | **"Zona de Guerra"**. Isolamento total (Air-gapped via Firewall). Habitantes: VM de Pentest (Kali), Targets vulneráveis. Bloqueio total de saída para a LAN. |

* **Regras Críticas de Firewall (Conceito):**
    * `MGMT` só pode ser acessada via VPN (WireGuard) ou fisicamente de uma porta específica do switch (Admin).
    * `IOT` não pode iniciar conexões com nada localmente.
    * `DMZ/DANGER` não acessa internet (para evitar vazamento de malware reverso) e não acessa nenhuma VLAN local.
    * `SERVER` (Nostr Relay) aceita conexões externas na porta do Traefik, mas não inicia conexões para a `TRUSTED`.
    * `Ansible Controller` (VLAN MGMT) tem permissão de saída **SSH (Porta 22)** para todas as outras VLANs para aplicar configurações, mas nenhuma outra VLAN acessa a MGMT.
