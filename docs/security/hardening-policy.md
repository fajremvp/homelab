### Padrão de Hardening e Segurança de Host

* **Padrão Base:** Adoção adaptada dos **CIS Benchmarks** (Center for Internet Security) Nível 1 para Debian e Alpine.
* **Gestão de Configuração:** Todo hardening é aplicado via **Ansible** (Infra-as-Code). Proibido alterações manuais ("Snowflake servers").

| Componente | Regra / Política | Aplicação |
| :--- | :--- | :--- |
| **Acesso SSH** | Autenticação **somente via Chave Ed25519** (PasswordAuthentication `no`). Usuário `root` bloqueado (PermitRootLogin `no`). Porta padrão alterada (Obscuridade como camada extra). | Todas as VMs/LXCs (Exceto Talos). |
| **Bastion Host** | NENHUMA máquina expõe SSH para a internet ou VLANs não confiáveis. Acesso administrativo é exclusivo via **VPN (WireGuard)** ou console do Proxmox na VLAN MGMT. | Geral. |
| **Sudo / Privilégios** | Acesso `sudo` restrito ao usuário admin, exigindo senha. Logs de auditoria de comandos habilitados. | Debian / Alpine. |
| **Firewall de Host** | Além do OPNsense (borda), cada host roda seu próprio firewall (`nftables` ou `ufw`) negando tudo exceto o essencial ("Defense in Depth"). | Todas as VMs. |
| **Atualizações** | **Unattended-Upgrades** habilitado para patches de segurança críticos automáticos. | Debian Stable (DockerHost). |
| **Kernel / Sysctl** | Desabilitar IPv6 se não usado, desabilitar forwarding de pacotes (exceto se for router), proteção contra ataques ICMP e SYN flood. | Debian / Alpine. |
| **CrowdSec** | Agente instalado em cada host enviando logs para o LAPI central. Detecta Brute Force local e reporta para bloqueio no OPNsense. | Todas as VMs expostas a serviços. |
| **Talos Linux** | O hardening é nativo (Imutável, Ephemeral, Read-only FS). Acesso à API do cluster protegido por mTLS com rotação de certificados. | Nodes do Cluster. |

### Diretrizes de Segurança para DockerHost

| Componente | Regra / Política | Motivação |
| :--- | :--- | :--- |
| **Docker Socket** | **Proibido montar `/var/run/docker.sock` em containers expostos.** Uso obrigatório de Socket Proxy com whitelist (GET only). | Impede que uma vulnerabilidade no Traefik/Portainer conceda acesso root ao Host. |
| **Filesystem** | Volumes persistentes em `/opt/` devem pertencer a usuário não-root. | Evita uso desnecessário de `sudo` e protege arquivos de sistema contra erro humano. |
| **Log Rotation** | Limite global de 30MB por container. | Prevenção de DoS por exaustão de disco (`no space left on device`). |
| **Web Ingress (Zero Trust)** | Todo painel administrativo web (Traefik, Portainer, etc) deve ser protegido pelo Middleware **Authentik ForwardAuth**. Proibida exposição de portas de gestão (8080, 9000) diretamente na rede; o acesso deve ser exclusivamente via domínio HTTPS autenticado. | Elimina vetores de ataque em interfaces administrativas desprotegidas. |
