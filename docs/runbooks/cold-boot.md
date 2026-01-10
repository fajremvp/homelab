## Recuperação de Energia (Power Recovery)
* **BIOS**: Configurada com Restore on AC Power Loss = Power On. Assim que a energia voltar, o servidor inicia e fica aguardando desbloqueio via Dropbear.
* **Switch**: Configurado para salvar VLANs na memória Flash, garantindo que a rede esteja pronta quando o SO do Proxmox terminar de carregar.
* **Sequência de Desbloqueio (Cold Boot):**
     1. **Energia Volta:** Servidor liga (Restore on AC Loss).
     2. **Initramfs:** Carrega o Dropbear SSH na porta 2222.
     3. **Acesso Remoto (Via Pi - Bypass):**
         - O Pi (conectado direto ao Modem) sobe a VPN Tailscale automaticamente.
         - Conectar na VPN de Emergência -> SSH para o Pi.
         - No Pi: Desbloquear a partição de dados (`cryptroot-unlock`).
         - No Pi: Usar a chave SSH resgatada para acessar o Proxmox (`ssh -p 2222 root@10.10.10.1`).
     4. **Boot:** O ZFS monta e os serviços (OPNsense, Vault, etc.) iniciam conforme a ordem de prioridade.

 	- Atualmente: (Usando DHCP do modem, sem ip dado pelo OPNsense ainda (10.10.10...)
    	- **Initramfs:** Carrega o Dropbear SSH na porta 2222 via interface `enp4s0`.
		- **Procedimento de Desbloqueio:**
    		1. No notebook Arch, garantir IP `10.10.10.99`.
    		2. Executar: `ssh -p 2222 root@10.10.10.1`.
    		3. No prompt do BusyBox, rodar: `cryptroot-unlock`.
    		4. Digitar a senha do LUKS e aguardar a queda da conexão.

### Ordem de Boot e Desligamento (Start/Shutdown Ordering)

A orquestração de boot é crítica para evitar "Race Conditions" (Serviço A tenta conectar no Serviço B antes de B estar pronto).
A configuração é definida em `Datacenter > Node > VM > Options > Start/Shutdown order`.

| Prioridade | VM/LXC | Startup Delay | Shutdown Timeout | Justificativa da Dependência |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **OPNsense (VM)** | `60s` | `120s` | **A Fundação (Rede).** Nada funciona sem roteamento/gateway. O delay de 60s garante que o Unbound, DHCP e Firewall carreguem totalmente antes de liberar o boot do próximo nível. |
| **2** | **AdGuard Home (LXC)** | `15s` | `15s` | **Resolução de Nomes (DNS).** Leve e rápido (Alpine). Deve subir imediatamente após a rede para garantir que `vault.home` e `auth.home` sejam resolvíveis para o resto da infra. |
| **3** | **Vault (VM)** | `30s` | `60s` | **Gestão de Segredos.** Deve estar "UP" (mesmo que selado) e acessível na porta 8200 antes que o Traefik tente iniciar. O delay permite que o serviço Vault suba e abra a porta TCP. |
| **4** | **Management (LXC)** | `30s` | `30s` | **Torre de Controle.** Necessário para rodar playbooks de correção ou automação logo após o boot. |
| **5** | **DockerHost (VM)** | `60s` | `180s` | **Camada de Aplicação.** Onde rodam Traefik, Authentik e Apps. Depende de Rede, DNS e Vault estarem estáveis. Shutdown longo configurado para permitir `docker stop` gracioso dos containers (evita corrupção de DB). |
| **6** | **Bitcoin Node (VM)** | `0s` | `300s` | **Carga Pesada.** Sobe por último. Não tem dependentes. Shutdown estendido (5 min) pois o `bitcoind` demora para descarregar o cache de memória para o disco (flush) ao desligar. |

* **Nota sobre Expansão:** Novos LXCs de serviço (ex: Unbound dedicado, Management) devem entrar na ordem **após** o AdGuard (Prioridade 2 ou 3) e **antes** do DockerHost, para garantir que serviços básicos estejam prontos antes das aplicações pesadas.
* **Kubernetes/Lab:** `Start at boot: No`. Devem ser ligados manualmente apenas quando necessários para economizar recursos.
