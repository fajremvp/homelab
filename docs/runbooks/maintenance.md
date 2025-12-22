### 7.5. Protocolo de Atualização de Kernel
- Risco: Atualizações de Kernel (pve-kernel) ou ZFS podem sobrescrever os hooks do initramfs.
- Procedimento Obrigatório: Após qualquer atualização de sistema (apt dist-upgrade) que envolva Kernel, ZFS ou Cryptsetup, executar antes de reiniciar:

		> `update-initramfs -u -k all

		> proxmox-boot-tool refresh`

	- Justificativa: Garante que os módulos de criptografia e o Dropbear (SSH) sejam incluídos na nova imagem de boot.