## Recuperação de Energia (Power Recovery)
* **BIOS**: Configurada com Restore on AC Power Loss = Power On. Assim que a energia voltar, o servidor inicia e fica aguardando desbloqueio via Dropbear.
* **Switch**: Configurado para salvar VLANs na memória Flash, garantindo que a rede esteja pronta quando o SO do Proxmox terminar de carregar.
* **Sequência de Desbloqueio (Cold Boot):**
     1. **Energia Volta:** Servidor liga (Restore on AC Loss).
     2. **Initramfs:** Carrega o Dropbear SSH na porta `2222` no IP `192.168.1.200`.
     3. **Acesso Remoto (Via Pi - Out-of-Band):**
         - O Pi (conectado direto ao Modem) sobe a VPN Tailscale automaticamente.
         - **Ação:** Conectar na VPN via Celular ou Notebook Arch.
         - **Conexão:** `ssh -p 2222 root@192.168.1.200` (A rota é provida pelo Pi).
         - **Desbloqueio:** No prompt BusyBox, rodar `cryptroot-unlock` e inserir a senha.
     4. **Boot:** O ZFS (Proxmox) monta e os serviços iniciam conforme a ordem de prioridade.

 	- Se já estiver na rede local ou conectado ao cabo de rede no modem, não é necessaŕio utilizar a VPN.

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
| **6** | **OrangeShadow (VM)** | `0s` | `600s` | **Carga Pesada.** Sobe por último. Não tem dependentes. Shutdown estendido (5 min) pois o `bitcoind`, por exemplo, demora para descarregar o cache de memória para o disco (flush) ao desligar. |

* **Nota sobre Expansão:** Novos LXCs de serviço devem entrar na ordem **após** o AdGuard (Prioridade 2 ou 3) e **antes** do DockerHost, para garantir que serviços básicos estejam prontos antes das aplicações pesadas.
* **Kubernetes/Lab:** `Start at boot: No`. Devem ser ligados manualmente apenas quando necessários para economizar recursos.
