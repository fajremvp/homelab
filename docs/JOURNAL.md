# Diário de Bordo

Este arquivo documenta a jornada, erros, aprendizados e decisões diárias.
Para mudanças estruturais formais, veja o [CHANGELOG](../CHANGELOG.md).

---
## 2025-12-24
**Status:** ⚠️ Resgate de Rede (Rollback)

**Foco:** Recuperação de Acesso e Simplificação de Rede

- **O Incidente:**
    - Após o sucesso inicial com o Dropbear, tentamos migrar para a topologia "Router-on-a-Stick" configurando VLANs (10, 20, 90) no OPNsense e no Switch.
    - **Resultado:** Perda total de acesso (Lockout). O Dropbear parou de responder e o Proxmox ficou inacessível.
- **Diagnóstico (A Causa Raiz):**
    1. **Hardcoding no Boot:** O arquivo `/etc/initramfs-tools/initramfs.conf` continha uma linha forçando IP Estático (`IP:10.10.10.1...`).
    2. **Desalinhamento:** O Switch foi configurado para esperar VLANs, mas o servidor bootava forçando um IP fora da sub-rede e sem tagging, causando falha de comunicação.
- **A Solução (O Resgate):**
    - **Physical Reset:** Reset físico do Switch TP-Link para configurações de fábrica (Rede Flat 192.168.0.x).
    - **Boot Config:** Editado `initramfs.conf` para remover o IP estático e definir `IP=dhcp`.
    - **Proxmox Config:** Editado `/etc/network/interfaces` para usar DHCP na `vmbr0`.
- **Lição Aprendida:**
    - **NUNCA** definir IPs estáticos no `initramfs` em ambiente de Homelab. Usar `IP=dhcp` e controlar a fixação de IP via reserva no Roteador (DHCP Static Lease).
    - O Dropbear (Desbloqueio) deve permanecer sempre na VLAN Nativa/Untagged (Rede "Burra") para garantir acesso de emergência independente do estado do OPNsense.
## 2025-12-22
**Status:** ✅ Sucesso Total

**Foco:** Otimização de Hardware e Router-on-a-Stick

- **Decisão Técnica:** A placa HP Quad-Port foi removida. O custo de complexidade de driver e energia não justificava o uso, dado que o switch TP-Link gerencia VLANs com perfeição.
- **Troubleshooting Dropbear:** Após a remoção da placa HP, o nome da interface mudou de `enp8s0` para `enp4s0`. Isso quebrou o desbloqueio remoto inicial.
    - *Correção:* Atualizei o `initramfs.conf` com `DEVICE=enp4s0` e fixei a porta `2222`. O teste de `cryptroot-unlock` via SSH no notebook Arch funcionou após limpar o `known_hosts`.
- **OPNsense:** WAN configurada com sucesso na VLAN 90. O IP foi obtido via DHCP do modem em modo DMZ.
## 2025-12-21
**Status:** ✅ Sucesso

**Foco:** Criptografia (FDE), Swap e Desbloqueio Remoto

- **LUKS:** Realizei a conversão pós-instalação do Proxmox para **LUKS2** (Full Disk Encryption) seguindo o guia manual. 
- **Swap:** Configurei um **ZFS Swap de 16GB** para evitar travamentos por exaustão de memória (OOM), já que o ZFS sem swap pode entrar em deadlock.
- **Dropbear:** Configurei o servidor SSH leve (Dropbear) no initramfs.
    - **Teste:** Reiniciei o servidor sem monitor. Conectei via SSH na porta temporária, digitei a senha do disco e o boot do Proxmox prosseguiu corretamente.

## 2025-12-20
**Status:** ✅ Sucesso

**Foco:** Dry Run (Instalação e Rede)

- **Instalação Base:** Instalei o Proxmox VE 9.1 para validar a detecção de hardware.
- **Rede:**
    - A interface Onboard foi identificada como `eno1` (Driver `r8169`).
    - A placa HP Quad-Port foi identificada corretamente (Driver `e1000e`).
    - **Latência:** Teste de ping direto registrou `0.2ms`.
- **Armazenamento:** O **ZFS Mirror (RAID 1)** foi montado e ativado no `rpool` com os dois NVMe Kingston.
- **Troubleshooting:** Tive dificuldade inicial para pingar o servidor (10.10.10.x) a partir do meu Arch Linux.
    - *Solução:* Era necessário ajustar as regras de entrada/saída no firewall do cliente (Arch), pois não há roteador intermediando a conexão física direta neste estágio.

## 2025-12-19
**Status:** ✅ Sucesso

**Foco:** Hardware Burn-in e BIOS

- **Validação de Memória:** Executei o **MemTest86 V11.5** por 6 horas e 17 minutos.
    - **Resultado:** 48/48 testes completados com **0 Erros**.
    - *Telemetria:* XMP validado a 3192 MT/s. A temperatura máxima da CPU ficou em 48°C, validando a instalação do cooler AK400.
![Evidência do MemTest86](../assets/benchmarks/MemTest86.jpeg)
- **Configuração da BIOS:** Apliquei as configurações críticas na Gigabyte B760M.
