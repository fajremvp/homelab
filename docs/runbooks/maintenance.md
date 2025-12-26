### Protocolo de Atualização de Kernel
- Risco: Atualizações de Kernel (pve-kernel) ou ZFS podem sobrescrever os hooks do initramfs.
- Procedimento Obrigatório: Após qualquer atualização de sistema (apt dist-upgrade) que envolva Kernel, ZFS ou Cryptsetup, executar antes de reiniciar:

		> `update-initramfs -u -k all

		> proxmox-boot-tool refresh`

	- Justificativa: Garante que os módulos de criptografia e o Dropbear (SSH) sejam incluídos na nova imagem de boot.

### Network Troubleshooting & Diagnostics
Se a conectividade das VLANs falhar, seguir este checklist de validação:
#### Validar Bridge do Proxmox (Camada 2)
Verificar se as VLANs estão permitidas na porta da VM (`tap100iX`):
```bash
bridge vlan show
# Saída Esperada para a interface da VM (ex: tap100i1):
# tap100i1  1 PVID Egress Untagged
#           20
#           50
