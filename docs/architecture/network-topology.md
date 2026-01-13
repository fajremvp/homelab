## Topologia de Rede e Segmentação (VLANs)
   - Status: Atualizado em 12/01/2026.
   - **Estratégia:** Router-on-a-Stick Virtualizado.
      - **Proxmox:** Atua como Switch Central (`vmbr0` VLAN Aware).
      - **OPNsense:** Atua como Roteador e Firewall.
      - **Segurança:** "Default Deny" entre VLANs.

## Conexões Físicas (Switch TP-Link)
   - Mapeamento das portas do switch físico para entender onde os cabos estão plugados.

| Porta | Conectado a | Descrição |
|:------|:------------|:----------|
| 1     | Servidor (Proxmox)| Interface `nic0`. Funciona como "Trunk Hybrid". Passa tráfego nativo (Proxmox IP) + todas as VLANs (VMs). |
| 2     | Access Point (AP) | Wi-Fi. Transmite SSID Pessoal (VLAN 20) e Guest/IoT (VLAN 50). |
| 8     | Modem (ISP)       | Uplink de Internet. Entrega DHCP na rede nativa `192.168.0.x`. |

## Mapeamento Lógico (Proxmox)
   - Como o Linux enxerga os cabos.

| Interface | Tipo | Função Real |
|:----------|:-----|:------------|
| nic0        | Física  | O cabo vermelho na Porta 1. Carrega tudo. Nota: Durante o boot (Initramfs), o Dropbear SSH escuta aqui (Porta 2222) com IP via DHCP para desbloqueio do disco. |
| vmbr0       | Bridge  | Switch virtual. Distribui tráfego para as VMs. |
| vmbr0 (IP)  | L3      | `192.168.0.200`. Endereço de emergência. O Proxmox reside na rede nativa (junto com o modem) para garantir acesso mesmo se o OPNsense falhar. |
| tap100i0    | Virtual | Cabo da LAN do OPNsense (VLAN 40 pendurada aqui). |
| tap100i1    | Virtual | Cabo da WAN/TRUNK do OPNsense (VLANs 10, 20, 30, 50 penduradas aqui). |

## Segmentação de Rede (VLANs)

| ID | Nome | CIDR | Descrição / Quem habita |
|:---|:-----|:-----|:------------------------|
| 1 | INFRA_WAN (Native) | 192.168.0.x | Tráfego Externo/Nativo. Rede do modem da operadora. Habitantes: Modem, WAN do OPNsense e Proxmox Host (.200) e Dropbear SSH (Boot/Unlock). |
| 10 | MGMT (Management) | 10.10.10.0/24 | "A Torre de Controle". Acesso restrito. Regra de Ouro: IPs Estáticos obrigatórios. Não dependem de DHCP. Porta de Emergência: Uma porta física do switch será configurada como "Untagged VLAN 10". Etiqueta Física (Protocolo de Crise): Colar uma etiqueta no switch contendo: "IP Emergência: 10.10.10.99 / GW: 10.10.10.1". Garante acesso rápido via notebook. Nota: O Proxmox migrará para cá apenas quando houver acesso Out-of-Band (Pi). Habitantes: LXC Management. |
| 20 | TRUSTED (Home) | 10.10.20.0/24 | "Dispositivos Pessoais". Rede de confiança média-alta. Habitantes: Notebook Arch, Celular (via AP Porta 2). Acesso permitido à Internet e a serviços na VLAN SERVER. |
| 30 | SERVER (Services) | 10.10.30.0/24 | "Produção". Onde rodam os serviços estáveis. Habitantes: VM DockerHost (Stalwart, Nostr, Vaultwarden, Forgejo), LXC AdGuard-Primary e futura VM do Bitcoin Node. Isolados, acessíveis apenas via portas específicas (ex: 443 via Traefik). |
| 40 | SECURE (Vault) | 10.10.40.0/24 | "O Cofre". Isolamento máximo. Sem acesso direto à internet (exceto update controlado e backups diários). Habitantes: VM Vault. Fisicamente separada na interface vtnet0. |
| 50 | IOT (Guest) | 10.10.50.0/24 | "A Selva". Dispositivos que não controlo e não confio. Sem acesso à VLAN de gerenciamento ou servidores. Habitantes: TV Smart, Lâmpadas, Visitantes (via AP Porta 2). |
| 60 | LAB (K8s/Dev) | 10.10.60.0/24 | "O Caos Controlado". [Futuro] Ambiente efêmero para testes e quebras. Habitantes: Cluster Kubernetes, VMs de teste. Se for comprometido, não afeta a Produção. |
| 99 | DMZ/DANGER | 10.10.99.0/24 | "Zona de Guerra". [Futuro] Isolamento total (Air-gapped via Firewall). Habitantes: VM de Pentest (Kali), Targets vulneráveis. Bloqueio total de saída para a LAN. |

## Matriz de Conectividade (Firewall)
   - Quem pode falar com quem?
   - Obs: detalhar ainda mais!
   
| Origem | Destino | Porta/Serviço | Justificativa |
|:-------|:--------|:--------------|:---------------|
| MGMT (10) | ANY | SSH (22) | Ansible precisa configurar os servidores. |
| TRUSTED (20) | ANY | SSH (22) | Acesso a todos os servidores (Arch). |
| TRUSTED (20) | SERVER (30) | HTTPS (443) | Acessar serviços e painéis (Vaultwarden, Grafana, Traefik...). |
| TRUSTED (20) | SERVER (30) | UDP 53 (DNS) | Clientes usam o AdGuard (10.10.30.5) para resolver nomes. |
| TRUSTED (20) | SECURE (40) | SSH (22) | Desbloquear o Vault. |
| SERVER (30) | SECURE (40) | TCP 8200 | DockerHost busca segredos no Vault. |
| SERVER (30) | WAN | HTTPS/DNS | Updates e serviços. |
| SECURE (40) | WAN | - | BLOQUEADO (Exceto janela de backup e atualizações manuais). |
| IOT (50) | LOCAL | - | BLOQUEADO (Acesso somente à Internet). Dispositivos IoT usam AdGuard (10.10.30.5). |

## Estrutura de Interfaces (OPNsense)
   - Para referência de manutenção (Drivers VirtIO).
      - `vtnet0` (LAN Física Virtual):
         - Dedica-se a redes de alta segurança.
         - Carrega: VLAN 40 (Vault).
      - `vtnet1` (WAN Física Virtual):
         - Atua como "Trunk" principal.
         - Carrega: Tráfego Nativo (WAN) + VLANs 10, 20, 30, 50.
