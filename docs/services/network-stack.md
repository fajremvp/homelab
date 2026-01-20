### Rede, Segurança e Infraestrutura (Sempre ativos)

* **OPNsense (Firewall):** `[VM Dedicada - VirtIO Bridge]`
    * **Justificativa:** Roteador principal da rede. Utiliza placas de rede virtuais (VirtIO) ligadas às Bridges físicas do Proxmox. Isso permite que o Host e a VM compartilhem a conexão física sem hardware extra.
    * **Ingress:** Configurado com **NAT Port Forwarding** puro (Portas 80/443 WAN -> IP do Traefik). O SSL é terminado no Traefik.
 
* **Configurações de Virtualização (Obrigatório):**
        - **System > Settings > Tunables:**
            - `net.link.bridge.pfil_member`: 0
            - `net.link.bridge.pfil_bridge`: 1
        - **Interfaces > Settings:**
            - Hardware CRC: **Disable** (Check)
            - Hardware TSO: **Disable** (Check)
            - Hardware LRO: **Disable** (Check)
            - VLAN Hardware Filtering: **Disable** (Para compatibilidade com VirtIO/Proxmox).
    * **NAT:** Modo **Hybrid Outbound NAT** ativado. Regras manuais criadas para garantir saída das VLANs (`10.10.x.0/24`) pela WAN.

* **VPN 1: Acesso Remoto (Inbound - Tailscale (Plano Personal/Free)):** `[DockerHost]`
	* **Serviço**: Utilizará o Tailscale Oficial (Plano Personal/Free).
	* **Traffic Shaping (QoS):** Uso de **Limiters (Pipes)** no OPNsense atrelados a um Alias do IP do Bitcoin Node.
	    - Regra: "Source IP: Bitcoin Node" -> Upload Max: 50% da banda total. Prioridade: Low.
	    - Garante que a propagação de blocos não sature o upload (bufferbloat) derrubando chamadas VoIP/Jitsi.
    * **Justificativa:** Garante conexão imediata e robusta mesmo atrás de CGNAT (comum em provedores residenciais no Brasil), sem necessidade de IP público, VPS externo ou configurações complexas de porta. O tráfego é criptografado ponto-a-ponto.

* **VPN 2: Privacidade (Outbound - Cliente WireGuard):** `[VM - OPNsense]`
    * **Justificativa:** Para o servidor acessar a internet sem ser rastreado.
    * **Configuração:** O OPNsense atuará como cliente **WireGuard** (conectado à ProtonVPN).
    * **Kill Switch:** Regras de firewall forçarão o tráfego de certas VLANs (ex: Downloads) a sair *apenas* pelo túnel VPN.
* **VPN 3: Acesso de Emergência (Out-of-Band):** `[Raspberry Pi]`
    * **Justificativa:** Instância secundária do Tailscale/Headscale rodando diretamente no Pi.
    * **Cenário de Uso:** Se o Proxmox ou o DockerHost travarem (derrubando a VPN 1), eu conecto nesta VPN de emergência para acessar a VLAN de Gerenciamento (10) e reiniciar o servidor via IPMI/SSH ou acessar o console do Switch.
* **Tor (Gateway/Proxy):** `[VM - OPNsense (Policy)]`
    * **Justificativa:** A forma mais fácil de "alterar" é criar uma regra de roteamento no OPNsense. Assim, pode-se definir que certos IPs (ex: uma VM de "privacidade") tenham todo o tráfego roteado pela rede Tor, enquanto outros usam a VPN ou a WAN normal.
* **AdGuard Home e Unbound (DNS):**
    * **Estratégia de DHCP (Failover Automático):**
      - **VLAN TRUSTED/IOT (Clientes):** O OPNsense entrega via DHCP **dois endereços IP** de DNS simultâneos para garantir alta disponibilidade:
        1. **Primário:** `10.10.30.5` (LXC AdGuard).
        2. **Secundário:** `192.168.0.5` (Raspberry Pi Edge).
        - *Comportamento:* Os clientes alternam automaticamente para o Pi caso o servidor principal não responda (timeout), garantindo navegação ininterrupta durante manutenções sem intervenção do usuário.
      - **VLAN SERVER (Infraestrutura):** Recebem apenas o IP do **Gateway (OPNsense) ou 1.1.1.1**.
        - *Justificativa:* Garante que servidores nunca percam conectividade DNS (updates/NTP) mesmo se o container do AdGuard falhar ou estiver em loop de boot, evitando dependência cíclica.
      - **Definição dos Nós DNS:**
        * **Primário:** `[LXC Alpine]` - VLAN 30. Filtragem principal.
        * **Secundário:** `[Raspberry Pi]` - Rede Nativa. Configuração "Amnésica" (RAM Disk) para privacidade total em caso de roubo físico do nó de borda.
    * **Estratégia Anti-Loop:** O OPNsense (Router) usará seu próprio **Unbound nativo** (localhost) para resolver nomes de infraestrutura, garantindo que ele nunca dependa do AdGuard para bootar. O AdGuard será entregue apenas aos clientes (PCs/Celulares) via DHCP.
* **Traefik (Reverse Proxy):** `[DockerHost]`
    * **Justificativa:** "Portão de entrada" único. Roda no DockerHost para aproveitar a **Auto-Descoberta** de serviços via labels.
    * **Segurança:** Será configurado obrigatoriamente através de um **Socket Proxy** (`tecnativa/docker-socket-proxy`). **Atenção:** Configurar as variáveis de ambiente para liberar *apenas* `CONTAINERS=1` e `SERVICES=1` (GET), bloqueando POST/DELETE.
    * **Certificados Soberanos:** Utilizará Let's Encrypt via **DNS-01 Challenge** integrado à API de um registrar focado em privacidade (Ex: **Porkbun** ou **Njalla**). Isso permite gerar certificados válidos (Wildcard) sem expor as portas 80/443 para a internet pública e sem depender da Cloudflare.
    * **Split-Horizon:** O DNS público não terá registros apontando para seus IPs. A resolução de nomes (`*.home.seudominio.net` -> IP Local) será feita exclusivamente dentro da rede pelo **AdGuard Home**, garantindo invisibilidade externa.
* **Authentik (Provedor de Identidade - SSO/IAM):** `[DockerHost]`
	* **Justificativa:** Centraliza o gerenciamento de usuários (SSO) e o IAM para todos os serviços. Integra-se nativamente ao Traefik (via Forward Auth) para proteger aplicações que não possuem autenticação própria. Fornece OIDC, SAML, LDAP virtual e gerenciamento de MFA (WebAuthn/Passkeys), alinhando-se às práticas de mercado e "Zero Trust".
* **HashiCorp Vault (Gerenciador de Segredos):** `[VM Dedicada - VLAN 40]`
    * **Justificativa:** Servidor central de segredos. Isolamento total (Kernel e Rede) do DockerHost para impedir vazamento lateral.
    * **Segurança:** Protegido por autenticação quádrupla:
        1. **Firewall de Rede (OPNsense):** Isola a VLAN 40 e bloqueia saída para internet.
        2. **Firewall de Host (UFW):** Rejeita conexões na porta 8200 que não venham do IP exato do DockerHost.
        3. **Aplicação:** Protegido por Authentik (Forward Auth) na borda HTTP.
        4. **Dados:** Banco de dados criptografado (Sealed (3/5)) em repouso.
* **CrowdSec (Defesa Ativa):**
    * **Agente ("Cérebro"):** `[DockerHost]` - Roda como container junto às aplicações. Lê os logs locais (Traefik, Autenticação) diretamente, sem complexidade de envio por rede.
    * **Bouncer ("Músculo"):** `[VM - OPNsense]` - Instala o plugin `os-crowdsec` no OPNsense, que lê as decisões do Agente e aplica os bloqueios no firewall.
