# Diário de Bordo

Este arquivo documenta a jornada, erros, aprendizados e decisões diárias.
Para mudanças estruturais formais, veja o [CHANGELOG](../CHANGELOG.md).

---
## 2025-12-30
**Status:** ✅ Sucesso (DNS & Privacy)

**Foco:** Implementação do AdGuard Home e Gestão de DNS
- **Infraestrutura DNS (LXC Container):**
    - Criado Container LXC `101 (AdGuard-Primary)` baseado em Alpine Linux (3.23) na VLAN 30.
    - **Specs:** 1 Core, 256MB RAM, IP Estático `10.10.30.5`.
    - **Software:** AdGuard Home instalado via script oficial.
        - `curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v`, disponível [aqui](https://github.com/AdguardTeam/AdGuardHome
).
- **Configuração do Serviço (AdGuard):**
    - **Upstreams:** Configurados servidores DNS-over-HTTPS (Cloudflare/Quad9) para garantir privacidade e evitar interceptação de porta 53 pelo ISP.
    - **Reverse DNS:** Apontado para o OPNsense (`10.10.30.1`) para resolução correta de hostnames locais nos logs.
- **Integração de Rede (OPNsense DHCP):**
    - Alterado o servidor DNS entregue via DHCP para as VLANs **TRUSTED (20)** e **IOT (50)**:
        - **De:** `1.1.1.1` e `8.8.8.8` (Externos (Cloudflare e Google, respectivamente).
        - **Para:** `10.10.30.5` (Local (AdGuard)).
    - **Política de Resiliência:** A VLAN **SERVER (30)** teve seu DNS mantido em `1.1.1.1` para evitar dependência cíclica (o DockerHost não deve depender de um container vizinho para resolver nomes durante o boot).
- **Validação:**
    - Cliente Arch Linux (VLAN 20) renovou DHCP e confirmou recebimento do DNS `10.10.30.5` via `/etc/resolv.conf`.
    - Dashboard do AdGuard registrou queries vindas da rede TRUSTED e bloqueios ativos.
    - O mesmo foi realizado com a VLAN 50.
- Documentação do repo melhor documentada e formatada.
- Repo aberto.
## 2025-12-29
**Status:** ✅ Sucesso (Docker & Hardening)

**Foco:** Configuração do DockerHost e Ajuste de Firewall

- **Hardening SSH:**
    - Chaves Ed25519 copiadas do Arch Linux para o DockerHost.
    - **Configuração de Segurança:** Editado `/etc/ssh/sshd_config` para:
        * `PermitRootLogin no` (Bloqueio total de login direto como root via SSH).
        * `PasswordAuthentication no` (Autenticação por senha desativada; apenas chaves SSH).
        * `PubkeyAuthentication yes` (Autenticação por chave pública habilitada).
        * `ChallengeResponseAuthentication no` (Desativa métodos interativos/legados de autenticação).
        * `UsePAM yes` (Mantém PAM ativo para controle de sessão e políticas do sistema).
    - **Validação:** Login verificado com sucesso via chave; tentativa de login por senha rejeitada como esperado.

- **Instalação do Docker:**
    - Utilizado repositório oficial (método compatível com Debian Trixie/Bookworm).
    - Engine e Plugin Compose (v5.0.0) instalados.
    - Usuário adicionado ao grupo `docker` para execução sem root/sudo.
    - **Teste de Sanidade:** `docker run hello-world` executado com sucesso (Pull da imagem via WAN OK, Execução OK).

- **Incidente de Conectividade (Firewall):**
    - *Sintoma:* O Arch Linux (VLAN 20) não conseguia pingar ou conectar via SSH no DockerHost (VLAN 30), resultando em Timeout.
    - *Causa Raiz:* Esquecimento da política de "Default Deny". Embora a VLAN 30 tivesse permissão de saída (para internet), a VLAN 20 não tinha permissão explícita de **entrada/passagem** para a VLAN 30.
    - *Solução:* Criada regra de Firewall na interface **TRUSTED**:
        - **Action:** Pass
        - **Source:** TRUSTED net
        - **Destination:** Any (ou SERVER net)
        - **Justificativa:** Permite que dispositivos de gerenciamento acessem os servidores.
        - O mesmo foi feito com a VLAN 50 (IOT).
## 2025-12-28
**Status:** ⚠️ Resgate de Rede (Driver Migration)

**Foco:** Recuperação das VLANs após mudança para VirtIO

- **O Incidente:**
    - Ao verificar a VM `DockerHost`, notei que ela não pegava IP (estava com APIPA `169.254.x.x`).
    - No OPNsense, as interfaces **TRUSTED**, **SERVER** e **IOT** haviam desaparecido do painel de controle, restando apenas LAN e WAN.
- **Diagnóstico:**
    - A mudança do driver de rede da VM OPNsense (de `e1000` para `VirtIO`) alterou a nomenclatura das interfaces no BSD (de `em0` para `vtnet0/1`).
    - Isso quebrou a associação "Parent Interface" das VLANs, tornando-as órfãs e desativadas.
    - Identifiquei via MAC Address (`04:FD`) que a interface `vtnet1` (atualmente WAN) era, na verdade, a porta física configurada com Trunks no Proxmox.
- **Solução:**
    1. **Reparenting:** Reconfigurei as VLANs 20, 30 e 50 para usarem a interface correta (`vtnet1`) como pai.
    2. **Re-assignment:** Re-adicionei as interfaces lógicas que haviam sumido.
    3. **Re-IP:** Restaurei os IPs Estáticos (`10.10.x.1`) e serviços DHCP que foram limpos durante a falha.
- **Resultado:** A VM DockerHost obteve o IP `10.10.30.102` imediatamente após o fix.
## 2025-12-27
**Status:** ✅ Sucesso

**Foco:** Provisionamento do DockerHost e Segmentação VLAN 30

- **Infraestrutura de Rede (VLAN 30 - SERVER):**
    - Configurada interface lógica no OPNsense (`10.10.30.1/24`) com DHCP ativado (`.100` a `.200`).
    - Validado isolamento: `ping` da VLAN 20 (Trusted) para 50 (IoT) falha como esperado (Bloqueio padrão).
    - Regras de Firewall: Criada regra temporária "Pass All" na VLAN 30 para permitir instalação de pacotes.
- **Computação (VM DockerHost):**
    - Criada VM ID `105` (Debian 13 Minimal (somente com SSH Server e Standard system utilities)).
    - **Specs:** 2 vCores (Host), 8GB RAM (Static), 32GB Disk (VirtIO Block).
    - **Rede:** Interface VirtIO com **Tag 30** definida no Proxmox.
    - **Validação:**
        - VM obteve IP `10.10.30.x` automaticamente.
        - Conectividade externa (WAN) funcionando via NAT Híbrido.
        - Acesso SSH verificado a partir da VLAN 20 (Trusted).
## 2025-12-26
**Status:** ✅ Sucesso Crítico (Rede Funcional)

**Foco:** Troubleshooting de VLANs, Switch e Roteamento OPNsense

- **O Incidente:** O DHCP não chegava aos clientes via Wi-Fi (VLANs 20/50) e, quando chegava (após fix), não havia navegação.
- **Diagnóstico e Soluções (Post-Mortem):**
    1. **Proxmox Bridge Dropping Tags:** A bridge `vmbr0` (VLAN Aware) estava descartando pacotes taggeados (20, 50) antes de entregá-los à VM.
        - *Correção:* Adicionado `bridge-vids 2-4094` em `/etc/network/interfaces` no Host.
        - *Correção:* Adicionado `trunks=20;50` na configuração da interface de rede da VM (`/etc/pve/qemu-server/100.conf`).
    2. **Conflito de Roteamento (Routing Loop):** A interface LAN (`192.168.0.250/24`) e WAN (`192.168.0.50/24`) estavam na mesma sub-rede. O kernel do OPNsense entrava em conflito de rota ao tentar responder a pacotes de outras VLANs, causando erro *"Provide a valid source address"* no Ping.
        - *Solução Definitiva:* Alterado IP da LAN para `192.168.99.1/24` para isolar as redes.
    3. **Hardware Offloading (VirtIO):** Pacotes DHCP chegavam corrompidos/descartados.
        - *Ajuste:* Desativado Hardware CRC, TSO e LRO nas configurações do OPNsense.
    4. **Firewall Block:** VLANs novas vêm com "Default Deny".
        - *Ajuste:* Criadas regras de "Pass All" e configurado Outbound NAT Híbrido.
## 2025-12-25
**Status:** 🔄 Troca de Hardware

**Foco:** Aquisição de Storage para Bitcoin Node

- **Problema Logístico:** O SSD SanDisk (comprado em 14/12) entrou em estado de atraso indefinido no Mercado Livre ("Em preparação" por 10 dias). Compra cancelada para evitar parada no projeto.
- **Revisão Técnica:** Aproveitei o incidente para reavaliar a especificação. Identifiquei que o SanDisk Plus é **DRAM-less**. Para um Full Node Bitcoin, isso seria catastrófico durante o IBD (Initial Block Download), pois o esgotamento do cache SLC derrubaria a velocidade de escrita drasticamente.
- **Decisão:** Adquirido **Samsung 870 EVO 2TB** (Envio Full).
    - Embora o custo seja marginalmente maior, ele possui **2GB de Cache LPDDR4** e controlador MKX. Isso garante que a sincronização da blockchain ocorra na velocidade máxima da interface SATA, economizando dias de espera futura.
    - A placa de rede HP NC364T (incompatível) devolvida também serviu para abater a diferença de custo.
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
