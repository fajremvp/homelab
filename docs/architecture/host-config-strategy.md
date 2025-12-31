# Estratégia de Configuração do Host (Proxmox VE)

Este documento define a configuração declarativa do Bare Metal. O objetivo é garantir que o Host seja resiliente a reboots, atualizações de kernel e falhas de rede, mantendo a segurança dos dados em repouso.

## Parâmetros de Boot e Kernel

A configuração de boot foi simplificada para evitar "Boot Loops" causados por hardcoding de rede.

* **Bootloader (GRUB/ZFS Boot):**
    * **Limpeza de Parâmetros:** Removi parâmetros complexos como `ip=...` direto no kernel line. A gestão de rede é delegada ao `initramfs` (fase inicial) e ao `networking.service` (fase final).
    * **IOMMU:** Habilitado preferencialmente via BIOS. Parâmetros como `intel_iommu=on` são opcionais se a BIOS já expõe os grupos IOMMU corretamente para Passthrough.

* **Desbloqueio Remoto (Dropbear no Initramfs):**
    * **Estratégia Anti-Lockout:** O `initramfs.conf` está configurado com `IP=dhcp`.
    * **Justificativa:** Isso garante que, se eu levar o servidor para outra casa ou mudar o roteador, ele pegará um IP novo automaticamente e permitirá o desbloqueio via SSH, sem ficar preso tentando acessar um Gateway estático inexistente.
    * **Interface:** Definida como `DEVICE=enp4s0` (nome nativo do hardware) para garantir que o Dropbear suba a placa correta antes mesmo do sistema operacional renomeá-la.

## Identidade de Rede e Interfaces

Para evitar que uma atualização do Debian/Proxmox troque os nomes das placas (ex: `eth0` virar `eth1`) e evite que eu exponha a interface de gerenciamento à Internet, usei nomenclatura determinística.

* **Fixação de Nomes (udev/systemd):**
    * **Interface Física:** `nic0` (Renomeada a partir do MAC Address da placa onboard/LAN).
    * **Interface Wireless:** `wlp5s0` (Mantida desligada/manual por segurança).

* **Topologia de Gerenciamento (Estado Atual):**
    * **IP de Acesso:** `192.168.0.200` (Rede Flat / WAN Nativa).
    * **Justificativa Temporária:** Para recuperação de desastres e estabilidade inicial, o Proxmox está acessível na mesma faixa de IP do modem da operadora. Isso elimina a dependência do OPNsense (VM) para acessar o Host físico.
    * **Bridge `vmbr0`:** Configurada como **VLAN Aware**. Isso permite que ela atue como um "Switch Virtual Inteligente", passando tráfego taggeado (VLAN 20, 30, 50) para as VMs, enquanto mantém o Host acessível na rede nativa.

## Armazenamento e Criptografia (FDE)

O sistema utiliza criptografia total de disco (Full Disk Encryption) sobre ZFS Mirror.

* **Otimização NVMe (`/etc/crypttab`):**
    * **Flags de Performance:** Recomenda-se o uso de `perf-no_read_workqueue` e `perf-no_write_workqueue`.
    * **Efeito:** Essas flags instruem o kernel a bypassar filas de agendamento de criptografia, reduzindo a latência de leitura/escrita em SSDs NVMe de alta velocidade.
    * **Discard/TRIM:** Habilitado (`discard`) para garantir que o SSD libere blocos não utilizados, preservando a vida útil e performance.

* **Swap Seguro (ZFS ZVOL):**
    * **Dispositivo:** `/dev/zd64` (16GB).
    * **Segurança:** O Swap reside dentro do pool ZFS criptografado (herança). Isso impede que fragmentos de memória (senhas, chaves) vazem para o disco em texto plano.
    * **Agressividade:** `vm.swappiness = 1`. O sistema só usará swap se a RAM estiver **absolutamente esgotada**, evitando degradação de performance do ZFS.

## Independência de Infraestrutura

* **Sincronização de Tempo (NTP):**
    * O Host deve apontar para servidores NTP confiáveis (ex: `time.cloudflare.com` ou `ntp.br`). Em uma fase futura, pretendo apontar para o Raspberry Pi (GPS/RTC) para soberania total de tempo.
* **Resolução de Nomes (`/etc/hosts`):**
    * Hostnames críticos (como o próprio `homelab`) são definidos estaticamente para garantir que o cluster funcione mesmo sem o serviço de DNS (AdGuard) estar no ar.

## Código de Referência da Rede (`/etc/network/interfaces`)

Configuração validada em 30/12/2025 para operação estável:

```bash
auto lo
iface lo inet loopback

# Interface Física Renomeada (L2 Pura)
iface nic0 inet manual

# Interface Wi-Fi (Desativada)
iface wlp5s0 inet manual

# Bridge Principal (Gerenciamento + VM Traffic)
auto vmbr0
iface vmbr0 inet static
    address 192.168.0.200/24
    gateway 192.168.0.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 2-4094
    # bridge-vids 2-4094 garante que as VLANs criadas no OPNsense trafeguem livremente.
