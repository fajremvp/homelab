## Configuração Lógica do Host (Proxmox VE)

  * **Parâmetros de Boot (GRUB):**
  	- intel_iommu=on iommu=pt: Para Passthrough de dispositivos PCI.
  	- ip=10.10.10.1::10.10.10.254:255.255.255.0:proxmox:eno1:off : Crítico. Configura IP estático direto no Kernel. Garante que o Dropbear (SSH) esteja acessível para desbloqueio mesmo se o servidor DHCP (OPNsense/Pi) estiver offline.
  * **Fixação de Interfaces (Anti-Morte Súbita):**
      * Criação de regras de Link do Systemd (`/etc/systemd/network/10-wan.link`) vinculando os nomes das interfaces ao **MAC Address** físico.
      * **Objetivo:** Evita que atualizações de Kernel troquem `eth0` por `eth1` e exponham o servidor à WAN.
      * Nomes definidos para uso no arquivo interfaces: `eno1` (Onboard/LAN) e `enp1s0` (Intel/WAN).
  * **Sincronização de Tempo (Soberania de Relógio):**
      * O Proxmox deve ser configurado para usar o **IP do Raspberry Pi** (VLAN 10) como servidor NTP `Stratum 1` preferencial.
      * Garante que TOTP, Logs e Bitcoin funcionem mesmo em boot sem internet ("Cold Start").
  * **Independência de DNS:** O arquivo `/etc/hosts` terá entradas estáticas para infraestrutura crítica, garantindo comunicação intra-cluster sem DNS.
  * **Criptografia e Performance (`/etc/crypttab`):**
      - Configuração obrigatória para garantir throughput próximo ao nativo nos SSDs NVMe:
      ```bash
      # UUIDs dos SSDs (Exemplo)
      luks-nvme0n1p3 UUID=xxxx-xxxx-xxxx-xxxx none luks,discard,initramfs,perf-no_read_workqueue,perf-no_write_workqueue
      luks-nvme1n1p3 UUID=yyyy-yyyy-yyyy-yyyy none luks,discard,initramfs,perf-no_read_workqueue,perf-no_write_workqueue
      ```
  * **Swap de Emergência (ZFS):**
      - **Guia:** [Enable swap with ZFS](https://github.com/mr-manuel/proxmox/blob/main/zfs-swap/README.md).
      - **Configuração:** Swap configurado em ZVOL com `vm.swappiness` baixo (10) para evitar OOM Killer em casos extremos, sem desgastar o SSD desnecessariamente.

  * **Configuração de Rede (`/etc/network/interfaces`):**
      * **Porta Física 1 (eno1 - LAN/Trunk): Conectada ao Switch → Bridge `vmbr0` (VLAN-aware, IP 10.10.10.1 na VLAN 10).
      * **Porta Física 2 (enp1s0 - WAN): Conectada ao Modem → Bridge `vmbr1` (Sem IP, modo transparente).
      * **Código de Configuração:**

<!-- end list -->

```bash
        # LAN Bridge (VLAN-Aware para todas as VLANs)
        auto vmbr0
        iface vmbr0 inet static
            address 10.10.10.1/24
            gateway 10.10.10.254  # IP do OPNsense
            bridge-ports eno1     # Nome fixado via Systemd Link (Anti-Troca)
            bridge-stp off
            bridge-fd 0
            bridge-vlan-aware yes
            bridge-vids 10 20 30 40 50 60 99
        
        # WAN Bridge (SEM IP - Transparente para OPNsense)
        auto vmbr1
        iface vmbr1 inet manual
            bridge-ports enp1s0   # Nome fixado via Systemd Link (Anti-Troca)
            bridge-stp off
            bridge-fd 0
            # CRÍTICO: Sem endereço IP para não expor Proxmox à WAN
```

* **Segurança da WAN:** A `vmbr1` atua como um "cabo virtual" transparente para o OPNsense, sem expor o Proxmox à internet.
