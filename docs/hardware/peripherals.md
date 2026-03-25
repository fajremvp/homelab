# Infraestrutura e Periféricos

## Modem da Operadora (Untrusted Edge)

### Função
- Gateway de acesso à Internet.
- Ponto de borda tratado como rede pública e não confiável.

### Configuração Crítica
- **Wi-Fi:** Totalmente desabilitado (2.4 GHz e 5 GHz).
  - *Motivo:* Eliminar vetores de ataque sem fio e evitar interferência com o Access Point dedicado.

### Topologia de Cabos (Router-on-a-Stick)
- **Porta LAN 1:** Conectada à **Porta 8** do Switch TP-Link.
- **Porta LAN 2:** (Livre).
- **Porta LAN 3:** Conectada ao Raspiberry Pi.
- **Porta LAN 4:** (Livre).

---

## UPS (Nobreak)

### Intelbras Gamer Ultimate 1000 VA / 700 W
- **Status:** Homologado e Ativo em Produção (Validado em 26/02/2026).
- **Carga Operacional:** ~165W Constante (Servidor + Switch + AP + Modem + RPi).
- **Especificações Elétricas:**
  - Topologia: Interativo.
  - Forma de Onda no modo bateria: **Senoidal Pura** (Obrigatório para a fonte MSI com PFC Ativo).
  - Bateria Interna: 2 × 12 V 7 Ah (Barramento de 24 V, Chumbo-ácido).
  - Fator de Potência: 0,7.
  - Tempo de Transferência: <10 ms.
- **Gerenciamento e Integração (Linux/NUT):**
  - **Interface:** Porta Serial USB.
  - **Identificação (lsusb):** `ID 0764:0601 Cyber Power System, Inc. PR1500LCDRT2U UPS`
  - **Driver:** `usbhid-ups`
  - **Topologia:** USB → Raspberry Pi (NUT Master) → Rede → Proxmox (NUT Slave).

  - **Ergonomia e Ambiente (Sala):**
    - LED Frontal: Fixado em **Ciano** para uniformidade estética com o servidor DeepCool.

---

## Switch Gerenciável — TP-Link Omada TL-SG2008 (8× Gigabit)

### Função
- Switch de acesso L2 e segmentação de rede via VLANs.
- Ponto central da topologia interna.

### Configuração Crítica
- **Modo:** L2 estrito.
- **VLANs:** 10, 20, 30, 40, 50, 60, 99.
- **Persistência:** Configuração salva em **Startup-Config (Flash)** para garantir boot autônomo.
- **PortFast (Admin Edge):** Habilitado nas portas do servidor para evitar timeout de DHCP no boot.

### Prevenção de Deadlock
- O switch opera de forma autônoma, sem depender do Omada Controller (VM) para tráfego básico.
- Portas de Uplink configuradas como Trunk nativamente na flash.

### Especificações
- **Interfaces:** 8 × RJ45 Gigabit (10/100/1000 Mbps).
- **Padrões:** IEEE 802.1Q (VLAN), 802.1p (QoS).
- **Segurança:** Interface de gestão restrita à VLAN 10. Protocolos inseguros (Telnet/HTTP) desabilitados.

---

## Access Point (Wi-Fi) — TP-Link Omada EAP610 (Wi-Fi 6 / AX1800)

### Função
- Fornece conectividade sem fio segmentada por VLANs (802.1Q).
- Unico emissor de rádio da infraestrutura (Wi-Fi da ISP desabilitado).
- Mapeamento Multi-SSID:
  - SSID "Homelab_Trusted" → VLAN 20
  - SSID "Homelab_IoT" → VLAN 50

### Configuração de Rádio (RF Tuning Enterprise)
A configuração foi otimizada para ambientes de apartamento (alta interferência):
- **Band Steering:** `Prefer 5GHz` (Força roaming inteligente para 2.4 GHz em áreas de sombra).
- **Rádio 2.4 GHz (Penetração & IoT):** Canal Fixo (6), Largura Estreita de **20MHz** (mitiga interferência).
- **Rádio 5 GHz (Velocidade Bruta):** Canal Auto, Largura de **80MHz**.
- **Multiplexação:** Protocolo **OFDMA** habilitado nativamente para baixar latência de dispositivos concorrentes.
- **Gerenciamento:** IP Fixo `192.168.1.10`, VLAN 1 (Untagged). Time Sync via `a.ntp.br`.

### Especificações
- **Padrão:** Wi-Fi 6 (802.11ax), retrocompatível com ac/n/g/b/a.
- **Frequência:** Dual-Band simultâneo (2.4 GHz e 5 GHz).
- **Antenas:** 4 internas.
- **Porta:** 1× Gigabit Ethernet (Suporte a PoE).

---

## Gerenciamento Out-of-Band — Raspberry Pi 4 (4 GB)

### Função
- Gerenciamento independente do servidor principal.
- Execução do **NUT Server** (Monitoramento de Energia).
- **Stack de DNS Soberano:** AdGuard Home + Unbound.
- **VPN de Emergência:** Acesso remoto garantido mesmo com Proxmox offline.

### Hardware Base
- **Modelo:** Raspberry Pi 4 Model B.
- **CPU:** Broadcom ARM Cortex (1.5 GHz).
- **RAM:** 4 GB.
- **Rede:** Gigabit Ethernet.

### Acessórios e Expansão (Instalados)

#### Fonte de Alimentação Dedicada — CanaKit (Oficial-equivalente)
- **Especificação:** 5V / 3.5A (USB-C, sem Power Delivery).
- **Marca:** CanaKit (Referência internacional para Raspberry Pi).
- **Cabo:** 18 AWG espesso, comprimento ~1,5m.
- **Certificação:** UL Listed.
- **Recursos Elétricos:** Filtro de ruído integrado para estabilidade sob carga contínua.
- **Justificativa Técnica:** Fonte comprovadamente estável para Raspberry Pi 4 com SSD USB 3.0, eliminando eventos de undervoltage e throttling sob carga. Além disso, fontes comuns de celular (ou genéricas de 3A) causam queda de tensão (*Brownout*) ao alimentar SSDs via USB 3.0, resultando em erros de I/O (`uas_eh_device_reset_handler`) e corrupção de dados. A amperagem extra (3.5A) oferece a margem necessária para estabilidade 24/7.

#### Chassis e Refrigeração (Case ABS)
- **Material:** ABS Plástico (Não bloqueia sinais Wi-Fi/Bluetooth).
- **Térmica:** Dissipadores de alumínio + Cooler ativo (Fan).

#### Módulo de Relógio (RTC) — DS3231
- **Interface:** GPIO (I2C).
- **Função:** Mantém o horário do sistema preciso sem internet (NTP Stratum 1 de emergência).

#### Cabeamento de Gerenciamento
- **Cabo UPS:** USB-A para USB-B (3m) — Conexão de dados do Nobreak.
- **Cabo Console:** Micro HDMI para HDMI (1.5m, pontas banhadas a ouro) — Diagnóstico local de vídeo.

---

## Armazenamento Principal (Raspberry Pi)

### SSD Externo — Rise Mode Gamer Line 120 GB
- **Interface:** SATA III (6 Gb/s).
- **Performance:** Leitura ~530 MB/s / Escrita ~520 MB/s.
- **MTBF:** 2.000.000 horas.

### Case Externo USB 3.0
- **Interface:** USB 3.0 (até 6 Gbps).
- **Material:** Acrílico transparente.
- **Compatibilidade:** SSD SATA 2.5".
- **Chipset:** JMicron (`ID 152d:0583`).
- **Compatibilidade:** Requer `usb-storage.quirks=152d:0583:u` no Kernel do Linux para operar de forma estável (Modo UAS desativado).

### Estratégia de Segurança (Split Storage)
1.  **Conexão Física:** O Pi conecta-se direto ao Modem (não ao Switch interno).
2.  **Partição 1 (Boot/Sistema):** OS, VPN, DNS. Permite boot da rede de emergência.
3.  **Partição 2 (LUKS2):** Dados sensíveis (Chaves SSH, Configs NUT). Montagem manual pós-autenticação.
4.  **Justificativa:** Resolve o deadlock "Ovo e Galinha" de acesso remoto e elimina corrupção de cartões SD.

---

## Cabeamento de Rede

A infraestrutura de rede física utiliza exclusivamente cabos CAT6 100% cobre para garantir estabilidade, baixa latência e suporte pleno a conexões Gigabit (1000BASE-T) entre os nós críticos e estações de trabalho.

### Patch Cords de Interconexão (Infraestrutura Base)
- **Status:** Ativos em Produção.
- **Função:** Interligação de curta distância entre os ativos principais do rack (Modem ISP ↔ Switch TP-Link ↔ Servidor Proxmox ↔ Access Point ↔ RPi).
- **Especificações Técnicas:**
  - **Fabricante/Modelo:** Furukawa Soho Plus CAT6 (U/UTP 24AWG).
  - **Comprimento:** 1,5 metros (Kit com 5 cabos).
  - **Material Condutor:** 100% Cobre Eletrolítico Nu (Fio Sólido), minimizando atenuação e perda de pacotes.
  - **Conectores:** RJ-45 (Storm Tech) crimpados de fábrica.
  - **Revestimento:** PVC Retardante a Chama (Normas CM/CMX, IEC 60332-1-2).
  - **Normas Atendidas:** ANSI/TIA-568-C.2 Category 6, ISO/IEC 11801.

### Cabo de Uplink do Desktop (Acesso Direto)
- **Status:** Homologado e Ativo em Produção (Implementado em 24/03/2026).
- **Função:** Conexão gigabit primária entre o Desktop Pessoal e o Switch TP-Link (Porta 3), substituindo a conexão Wi-Fi para mitigar picos de *jitter* e estabilizar a latência (ICMP médio de ~11.9ms c/ `mdev` de 0.3ms) no acesso à rede segura (VLAN 20).
- **Especificações Técnicas:**
  - **Fabricante/Modelo:** Furukawa Sohoplus CAT6 (U/UTP 24AWG).
  - **Comprimento:** 10 metros.
  - **Material Condutor:** 100% Cobre Nu (Cabo Sólido), garantindo integridade de sinal em média distância sem perda de SNR.
  - **Conectores:** RJ-45 Blindados EZ-Crimp, com capas de proteção.
  - **Frequência / Banda:** 250 MHz.
  - **Link Negociado:** 1000Mb/s (1 Gbps) Full-Duplex.

---
## Hardware Legado / Descartado
### Placa de Rede PCIe - HP NC364T (Quad-Port)
- **Status:** Removida do sistema em 2025-12-22.
- **Motivo:** Incompatibilidade de drivers e redundância técnica após implementação de VLAN Trunking (802.1Q) no Switch TP-Link.

### Fonte Compatível Com Raspberry Pi4 Tipo C 5v 3a Botão U1002
- **Status:** Removida do sistema em 2026-01-15.
- Fonte genérica com histórico real de undervoltage em Pi 4 + SSD.
- Não é confiável para operação 24/7 com carga USB contínua (SSD + UPS).
- **Motivo:** Produto entregue com conector incompatível (Não era USB-C) e qualidade duvidosa para missão crítica.

### UPS (Nobreak) — Ragtech M2 1200VA / 840W (Senoidal Puro)
- **Status:** Devolução iniciada em 2026-01-17.
- **Motivo:** Incompatibilidade com Linux/NUT.
- **Diagnóstico:** O chipset Microchip (`04d8:000a`) utiliza um protocolo binário proprietário (resposta `0xca` para comandos padrão), impedindo o monitoramento aberto sem engenharia reversa instável.

### UPS (Nobreak) — NHS Gamer Play Senoidal 1000VA
- **Status:** Devolvido em 28-01-2026.
- **Motivo:** Incompatibilidade de Protocolo.
- **Diagnóstico:** O modelo utiliza um protocolo proprietário ou implementação USB não-standard que não foi reconhecida pelos drivers `blazer_usb` ou `nutdrv_qx` do NUT, impedindo o monitoramento automatizado.

### Micro Ventoinha DC (Cooler do RPi Case)
- **Status:** Removida permanentemente em 2026-03-01.
- **Motivo:** Falha mecânica precoce no rolamento causando ruído irregular e vibração.
- **Resolução:** Testes térmicos sob estresse provaram que a refrigeração passiva (dissipadores) é suficiente para a carga da infraestrutura, eliminando a necessidade de reposição da peça.
