### 3. Topologia de Rede e Segmentação (VLANs)

* **Estratégia:** Router-on-a-Stick (Single NIC). O Switch TP-Link atua como multiplexador de tráfego WAN/LAN.
* **Modelo de Segurança:** "Default Deny" entre VLANs. OPNsense é o único roteador.
* **Sobrevivência (Anti-Lockout):** Utilização da VLAN Nativa (1) para acesso de emergência ao Hypervisor e Dropbear, independente das VLANs lógicas do OPNsense.

| VLAN ID | Nome | CIDR | Descrição / Quem habita |
| :--- | :--- | :--- | :--- |
| **1** | `EMERGENCY` | `DHCP (ISP)` | **"Anti-Lockout" (Rede Suja)**. Rede nativa do Modem/Roteador da Operadora (192.168.x.x). **Função:** Acesso direto ao console do Proxmox e Dropbear SSH caso o OPNsense ou o Switch de VLANs falhem. **Risco Aceito:** Compartilha segmento L2 com o Modem da operadora (necessário por limitação de hardware - Single NIC). |
| **90** | `WAN_FIBRA` (Internet) | `DHCP` | **Link de Uplink**. Tráfego da operadora encapsulado na VLAN 90 pelo Switch (Porta 8) e entregue ao OPNsense. **Isolamento:** Esta VLAN não se comunica com nenhuma outra no nível do Switch. |
| **10** | `MGMT` (Internal Ops) | `10.10.10.0/24` | **"Gestão Interna"**. Acesso às interfaces Web (Proxmox, OPNsense, Dashboards). **Restrição:** Acessível apenas via VPN (WireGuard) ou estação de trabalho autorizada na VLAN TRUSTED. Não acessível pela VLAN 1 por padrão (exceto rebuild). |
| **20** | `TRUSTED` (Home) | `10.10.20.0/24` | **"Dispositivos Pessoais"**. Rede de confiança média-alta. Habitantes: Notebook Arch, Celular, Desktop. Acesso permitido à Internet e, via regras restritas, a serviços na VLAN SERVER. |
| **30** | `SERVER` (Services) | `10.10.30.0/24` | **"Produção"**. Onde rodam os serviços estáveis. Habitantes: DockerHost (Stalwart, Nostr, Vaultwarden, Forgejo), Bitcoin Node. Isolados, acessíveis apenas via portas específicas (ex: 443 via Traefik). |
| **40** | `SECURE` (High Security) | `10.10.40.0/24` | **"O Cofre"**. Isolamento máximo. Acesso à internet restrito a updates críticos (Whitelist). Habitantes: HashiCorp Vault. |
| **50** | `IOT` (Untrusted) | `10.10.50.0/24` | **"A Selva"**. Dispositivos não confiáveis. Bloqueio total de acesso à rede local (Client Isolation recomendado no AP). Habitantes: TV Smart, Lâmpadas, Visitantes. |
| **60** | `LAB` (K8s/Dev) | `10.10.60.0/24` | **"Sandbox"**. Ambiente efêmero para testes destrutivos. Sem acesso à Produção ou MGMT. |
| **99** | `DMZ` | `10.10.99.0/24` | **"Zona Isolada"**. Para serviços expostos ou honeypots. Isolamento total (Air-gapped via Firewall). |

* **Regras Críticas de Firewall (Implementação):**
    * `EMERGENCY (VLAN 1)`: Acesso permitido **apenas** às portas 22 (SSH Proxmox) e 2222 (Dropbear). Bloqueado acesso à Web UI do OPNsense (exceto se regra de emergência for ativada manualmente).
    * `MGMT`: Só aceita conexões vindas da VPN ou de IPs específicos da `TRUSTED` (Admin Workstation).
    * `WAN_IN`: Bloqueio total (exceto portas abertas explicitamente para serviços na DMZ/SERVER via Port Forward).
