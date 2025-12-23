# Infraestrutura e Periféricos

## Modem da Operadora (Untrusted Edge)

### Função
- Gateway de acesso à Internet.
- Ponto de borda tratado como rede pública e não confiável.

### Configuração Crítica
- **Wi-Fi:** Totalmente desabilitado (2.4 GHz e 5 GHz).
  - *Motivo:* Eliminar vetores de ataque sem fio e evitar interferência com o Access Point dedicado.
- **DHCP:** Ativado.
  - Fornece endereços IP para a WAN do OPNsense e para o Raspberry Pi.
- **DMZ:** IP da interface WAN do OPNsense configurado como DMZ.
  - *Objetivo:* Evitar Double NAT e garantir encaminhamento direto de tráfego.

### Topologia de Cabos (Router-on-a-Stick)
- **Porta LAN 1:** Conectada ao Raspberry Pi (VPN de emergência).
- **Porta LAN 2:** Conectada à **Porta 8** do Switch TP-Link (VLAN 90 - WAN_FIBRA).
- **Porta LAN 3:** (Livre).

---

## UPS (Nobreak) — Ragtech M2 1200VA / 840W (Senoidal Puro)

### Função Crítica
- Proteção elétrica do servidor e equipamentos de rede.
- **Essencial para fontes com PFC ativo** (evita dano elétrico e instabilidade).
- Integração com gerenciamento de energia via **USB → Raspberry Pi (NUT Server)**.

### Especificações Técnicas
- **Potência:** 1200 VA / 840 W (Real).
- **Forma de onda:** Senoidal pura.
- **Tensão:** Entrada e Saída 220V (Monovolt).
- **Bateria:** 1 × 12V / 7Ah (Substituível).

### Recursos
- **Proteções:** Sub/Sobretensão, Surtos, Sobrecarga, Curto-circuito, Sobretemperatura.
- **DC-start:** Permite ligar os equipamentos mesmo sem energia da rua.
- **Auto-restart:** Religa automaticamente no retorno da energia.

### Integração
- Conectado via USB ao Raspberry Pi.
- Monitorado pelo **NUT (Network UPS Tools)**.
- Permite shutdown controlado (graceful shutdown) do servidor em falha prolongada.

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
- Fornece conectividade sem fio segmentada por VLAN.
- Mapeamento Multi-SSID:
  - SSID "Casa" → VLAN 20
  - SSID "IoT" → VLAN 50

### Especificações
- **Padrão:** Wi-Fi 6 (802.11ax), retrocompatível com ac/n/g/b/a.
- **Frequência:** Dual-Band (2.4 GHz e 5 GHz).
- **Antenas:** 4 internas.
- **Porta:** 1× Gigabit Ethernet (Suporte a PoE).

### Justificativa Técnica
- Wi-Fi 6 para maior eficiência com múltiplos clientes IoT.
- AP dedicado elimina riscos de segurança de modems de operadora.

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

#### Fonte de Alimentação Dedicada (U1002)
- **Especificação:** 5V / 3.0A (USB-C).
- **Cabo:** 18AWG (Bitola grossa para evitar *voltage drop*).
- **Recurso:** Botão Liga/Desliga físico (evita desgaste do conector USB-C em hard reboots).

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

### Estratégia de Segurança (Split Storage)
1.  **Conexão Física:** O Pi conecta-se direto ao Modem (não ao Switch interno).
2.  **Partição 1 (Boot/Sistema):** OS, VPN, DNS. Permite boot da rede de emergência.
3.  **Partição 2 (LUKS2):** Dados sensíveis (Chaves SSH, Configs NUT). Montagem manual pós-autenticação.
4.  **Justificativa:** Resolve o deadlock "Ovo e Galinha" de acesso remoto e elimina corrupção de cartões SD.

---

## Cabos de Rede — Furukawa Sohoplus Cat6

### Especificações
- **Tipo:** Cat6 U/UTP (Gigabit Ready).
- **Material:** 100% Cobre Nu (Sem CCA - Alumínio Cobreado).
- **Conectores:** RJ45 Storm Tech (Crimpados de fábrica).
- **Bitola:** 23/24 AWG.
- **Qualidade:** Padrão ANSI/TIA-568-C.2 e ISO/IEC 11801.

### Aplicação
- Interconexão de alta velocidade e estabilidade para todo o Homelab.

---
## Hardware Legado / Descartado
### Placa de Rede PCIe - HP NC364T (Quad-Port)
- **Status:** Removida do sistema em 2025-12-22.
- **Motivo:** Incompatibilidade de drivers e redundância técnica após implementação de VLAN Trunking (802.1Q) no Switch TP-Link.
