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

* **VPN 1: Acesso Remoto (Inbound - Tailscale):** `[DockerHost]`
	* **Função:** Porta de entrada fora de casa.
	* **Modo:** Subnet Router (`10.10.0.0/16`) com NAT Masquerading e IP Forwarding.
	* **Acesso:** Permite conexão a todos os serviços web (`*.home`), Dashboards e SSH dos servidores (exceto serviços rodando na LAN (192.168.1.x)).
	* **DNS:** Configurado via Split DNS para resolver domínios `.home` usando o AdGuard local (`10.10.30.5`).
	* **Segurança:** Acesso restrito via ACL ao e-mail do proprietário.

* **VPN 2: Privacidade (Outbound - Cliente WireGuard):** `[VM - OPNsense]`
    * **Justificativa:** Para o servidor acessar a internet sem ser rastreado.
    * **Configuração:** O OPNsense atuará como cliente **WireGuard** (conectado à ProtonVPN).
    * **Kill Switch:** Regras de firewall forçarão o tráfego de certas VLANs (ex: Downloads) a sair *apenas* pelo túnel VPN.

* **VPN 3: Acesso de Emergência (Out-of-Band):** `[Raspberry Pi]`
    * **Justificativa:** Instância secundária do Tailscale rodando diretamente no Pi.
    * **Cenário de Uso:** Acesso exclusivo para **Desbloqueio de Disco (Dropbear)** fora de casa.
    * **Segurança:** Protegido por ACLs estritas (`tag:rpi`) que permitem tráfego APENAS para `192.168.1.200:2222`. Movimento lateral bloqueado.

* **Tor (Gateway/Proxy):** `[VM - OPNsense (Policy)]`
    * **Justificativa:** A forma mais fácil de "alterar" é criar uma regra de roteamento no OPNsense. Assim, pode-se definir que certos IPs (ex: uma VM de "privacidade") tenham todo o tráfego roteado pela rede Tor, enquanto outros usam a VPN ou a WAN normal.
* **AdGuard Home e Unbound (DNS):**
    * **Estratégia de DHCP (Failover Automático):**
      - **VLAN TRUSTED/IOT (Clientes):** O OPNsense entrega via DHCP **dois endereços IP** de DNS simultâneos para garantir alta disponibilidade:
        1. **Primário:** `10.10.30.5` (LXC AdGuard).
        2. **Secundário:** `192.168.1.5` (Raspberry Pi Edge).
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
* **CrowdSec (Defesa Ativa):** Implementado em 24/01/2026
    * **Agente ("Cérebro"):** `[DockerHost]` - Centraliza a inteligência. Recebe logs do Traefik e Authentik.
    * **Bouncer ("Músculo"):** `[VM - OPNsense]` - Utiliza o plugin `os-crowdsec` configurado para consultar a LAPI remota. Aplica bloqueios em nível de kernel (pf) via Regras Flutuantes.
    * **Fluxo de Bloqueio:** Tentativa de ataque -> DockerHost detecta -> LAPI gera decisão -> Bouncer lê decisão -> IP bloqueado no Firewall.
    * **Limitação Atual:**
        - CrowdSec não executa remediação baseada em falhas de login do Authentik.
        - Defesa de identidade depende exclusivamente de MFA, políticas internas e rate-limit do próprio Authentik.
