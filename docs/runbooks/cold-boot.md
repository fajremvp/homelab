### 7.4. Recuperação de Energia (Power Recovery)
* **BIOS**: Configurada com Restore on AC Power Loss = Power On. Assim que a energia voltar, o servidor inicia o boot imediatamente, sem depender de rede ou periféricos.
* **Switch**: Configurado para salvar VLANs na memória Flash, garantindo que a rede esteja pronta quando o SO do Proxmox terminar de carregar.
* **Sequência de Desbloqueio (Cold Boot):**
     1. **Energia Volta:** Servidor liga (Restore on AC Loss).
     2. **Initramfs:** Carrega o Dropbear SSH na porta 2222.
     3. **Acesso Remoto (Via Pi - Bypass):**
         - O Pi (conectado direto ao Modem) sobe a VPN Tailscale automaticamente.
         - Conectar na VPN de Emergência -> SSH para o Pi.
         - No Pi: Desbloquear a partição de dados (`cryptsetup open ...`).
         - No Pi: Usar a chave SSH resgatada para acessar o Proxmox (`ssh -p 2222 root@10.10.10.1`).
         - Executar comando: `cryptroot-unlock` no Proxmox.
     4. **Boot:** O ZFS monta e os serviços (OPNsense, Vault, etc.) iniciam conforme a ordem de prioridade.

 	- Atualmente:
    	- **Initramfs:** Carrega o Dropbear SSH na porta 2222 via interface `enp4s0`.
		- **Procedimento de Desbloqueio:**
    		1. No notebook Arch, garantir IP `10.10.10.99`.
    		2. Executar: `ssh -p 2222 root@10.10.10.1`.
    		3. No prompt do BusyBox, rodar: `cryptroot-unlock`.
    		4. Digitar a senha do LUKS e aguardar a queda da conexão.

* **Ordem de Boot Automática (Startup Delays):**
	1. OPNsense: Priority 1 (Delay 0s). A rede precisa subir primeiro.
	2. Vault: Priority 2 (Delay 30s). Os segredos precisam estar disponíveis.
	3. DockerHost: Priority 3 (Delay 60s). Depende da Rede e do Vault.
	4. Bitcoin Node: Priority 4 (Delay 120s). Pesado, sobe por último.
	* Nota: Cluster Kubernetes e VMs de Lab não têm auto-boot configurado (Acionamento Manual).
