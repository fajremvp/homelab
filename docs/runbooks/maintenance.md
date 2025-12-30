## Protocolo de Atualização de Kernel
- Risco: Atualizações de Kernel (pve-kernel) ou ZFS podem sobrescrever os hooks do initramfs.
- Alterações em GRUB (ex: parâmetros de rede ou IOMMU) também exigem rebuild do initramfs e refresh do bootloader.
- Procedimento Obrigatório: Após qualquer atualização de sistema (apt dist-upgrade) que envolva Kernel, ZFS ou Cryptsetup, executar antes de reiniciar:

```bash
update-initramfs -u -k all
proxmox-boot-tool refresh
```
- Justificativa: Garante que os módulos de criptografia e o Dropbear (SSH) sejam incluídos na nova imagem de boot.

## Network Troubleshooting & Diagnostics

Se a conectividade das VLANs falhar, seguir este checklist de validação:

#### Validar Bridge do Proxmox (Camada 2)

Verificar se as VLANs estão permitidas na interface da VM ou CT (`tapXXXiY` ou `vethXXXiY`):

```bash
bridge vlan show
````

Saída esperada para a interface da VM (ex: `tap100i1`):

```text
tap100i1  1 PVID Egress Untagged
          20
          50
```

Se as tags `20` / `50` não aparecerem, o Proxmox está bloqueando o tráfego na bridge.
Verificar `bridge-vids` no `/etc/network/interfaces`.

#### Sniffer de Pacotes (Verificar se chega no OPNsense)

Rodar no shell do OPNsense (Opção 8) para verificar se o DHCP Discover chega:

```bash
# Verificar na interface correta (WAN ou VLAN, ex: vtnet1, vtnet0 ou VLAN_X)
tcpdump -i vtnet1 -n -e vlan

# OU filtrar apenas DHCP
tcpdump -i vtnet1 port 67 or port 68 -n -e
```

* **Não aparece nada:** problema no switch físico ou na bridge do Proxmox.
* **Aparece Request mas não Reply:** problema no serviço DHCP do OPNsense ou em regras de firewall.

#### Validar Roteamento e Saída

Se conecta mas não navega (“Connected without internet”):

* Verificar IP do cliente (`ip a` ou detalhes do Wi-Fi).
* Testar ping a partir do OPNsense:
  **Interfaces → Diagnostics → Ping**

  * **Source Address:** interface da VLAN (ex: `VLAN_50_IOT`)
  * **Target:** `8.8.8.8`

Erro **“Provide a valid source address”** indica:

* Interface sem IP atribuído, ou
* Conflito de rotas (WAN e LAN na mesma subnet).

## Verificações Pós-Manutenção (Obrigatórias)

Após qualquer manutenção crítica (kernel, rede, storage):

- Confirmar IP correto no host:
  - `ip a show vmbr0`
- Confirmar ausência de IP na WAN:
  - `ip a show vmbr1`
- Confirmar VLANs ativas:
  - `bridge vlan show`
- Confirmar swap ativo:
  - `swapon --show`
- Confirmar tempo sincronizado:
  - `chronyc tracking`
