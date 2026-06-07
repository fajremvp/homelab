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
tap105i1  1 PVID Egress Untagged
          10  <-- MGMT
          20  <-- TRUSTED
          30  <-- SERVER
          40  <-- SECURE
          50  <-- IOT
```

Se as tags `10` / `20` / `30` / `40` / `50` não aparecerem, o Proxmox está bloqueando o tráfego na bridge.
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
- Confirmar status da bateria e comunicação NUT L3 (Proxmox -> RPi):
  - `upsc intelbras@192.168.1.5 | grep ups.status` (Espera-se `OL` ou `OL CHRG`)

## Recuperação e Substituição de Disco (ZFS Root)

Este ambiente utiliza ZFS Mirror como root. Em caso de falha física de um SSD/NVMe do pool root, **não reinstalar o sistema**.

### Procedimento Oficial (Referência)
Guia completo para substituição de disco raiz mantendo boot, ZFS e criptografia:

https://github.com/mr-manuel/proxmox/blob/main/zfs-replace-root-disk/README.md

### Quando usar este guia
- Disco do mirror entra em estado DEGRADED ou FAULTED
- SMART acusa falha iminente
- Substituição preventiva de SSD/NVMe
- Erro de boot após perda de um dos discos do mirror

## Auditoria de Segurança Crítica (CrowdSec & OPNsense)

Se houver suspeita de falha na proteção perimetral, execute este checklist de 6 passos no `DockerHost` para validar o fluxo *End-to-End*:

1. **Ingestão (Olhos):** `docker exec -t crowdsec cscli metrics | grep docker:`
   * (Deve listar os parsers `docker:traefik` e `docker:authentik-server` não-zerados).
2. **Inteligência (Cérebro):** `docker exec -t crowdsec cscli metrics | grep traefik-logs`
   * (A coluna `Parsed` não pode estar vazia. Se estiver, o Traefik parou de gerar JSON).
3. **Whitelist (Proteção Interna):** `docker exec -t crowdsec cscli metrics | grep whitelists`
   * (Verifique se acessos da rede local `10.10.x.x` recebem "Hits" para evitar auto-banimento).
4. **Comunicação L3 (Nervos):** `docker exec -t crowdsec cscli bouncers list`
   * (O `opnsense-firewall` deve aparecer como `✔️ Valid`).
5. **Execução L3 (Músculo - No OPNsense via SSH):** `pfctl -t crowdsec_blocklists -T show | wc -l`
   * (Espera-se o retorno de milhares de IPs banidos em tempo real).
6. **Teste de Botão de Pânico (Simulação):**
   * Banir manual: `docker exec -t crowdsec cscli decisions add -i 1.1.1.1 -d 1h -R "Auditoria"`
   * Validar: O `Ntfy` deve apitar e o comando `pfctl -t crowdsec_blocklists -T show | grep 1.1.1.1` deve acusar bloqueio no OPNsense.
   * Rollback: `docker exec -t crowdsec cscli decisions delete -i 1.1.1.1`
