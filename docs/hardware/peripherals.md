# Infraestrutura e Periféricos

## Modem da Operadora (Untrusted Edge)

### Função
- Gateway de acesso à Internet.
- Ponto de borda tratado como rede pública e não confiável.

### Configuração Crítica
- **Wi-Fi:** Totalmente desabilitado (2.4 GHz e 5 GHz).
  - *Motivo:* Eliminar vetores de ataque sem fio e evitar interferência com o Access Point dedicado.
- **DHCP:** Ativado.
  - Fornece endereços IP para o Dropbear, a WAN do OPNsense e para o Raspberry Pi.

### Topologia de Cabos (Router-on-a-Stick)
- **Porta LAN 1:** Conectada à **Porta 8** do Switch TP-Link.
- **Porta LAN 2:** (Livre).
- **Porta LAN 3:** (Livre).
- **Porta LAN 4:** Conectada ao Raspiberry Pi.

---

## UPS (Nobreak) — NHS Gamer Play Senoidal 1000VA

### Identificação
- **Fabricante:** NHS
- **Modelo:** Gamer Play Senoidal 1000VA
- **Part Number:** 91.G0.010000
- **Status:** Adquirido em 21/01/2026 (Aguardando entrega).

### Especificações Elétricas
- **Potência:** 1000 VA / 600 W (Fator de Potência 0.6).
- **Forma de Onda:** **Senoidal Pura** (Obrigatório para fontes com PFC Ativo como a MSI MAG A750GL).
- **Entrada:** Bivolt Automático (120V - 220V) - *Full Range*.
- **Saída:** 120V (Padrão de fábrica).
- **Tomadas:** 6 × NBR 14136 (10A).
- **Proteções:** Curto-circuito, Sobrecarga, Sub/Sobretensão e Surtos (Varistor).

### Armazenamento de Energia
- **Baterias Internas:** 2 × 7Ah / 12V Chumbo-ácida VRLA (Sistema 24V).
- **Autonomia Estimada:** ~25 a 35 minutos (Considerando carga média do Homelab de ~160W).
- **Expansão:** Possui engate para módulo de bateria externa.

### Gerenciamento e Integração (Linux/NUT)
- **Interface:** USB tipo B.
- **Protocolo:** Compatível com **NHS / SEC2400** (MegaTec).
- **Driver NUT:** `blazer_usb` ou `nutdrv_qx`.
- **Topologia:** USB → Raspberry Pi (NUT Master) → Rede → Proxmox (NUT Slave).

### Justificativa Técnica
- **Protocolo Aberto:** Ao contrário do Ragtech (proprietário/binário), o NHS utiliza padrões de mercado documentados, garantindo monitoramento nativo no Linux sem "gambiarras".
- **Resiliência:** O banco de baterias em 24V oferece o dobro de autonomia comparado a nobreaks de entrada (12V), fundamental para evitar *flapping* (ligar/desligar) em oscilações curtas de energia.
- **Construção:** Gabinete metálico com pintura epóxi oferece melhor blindagem eletromagnética e dissipação térmica que carcaças de plástico ABS.

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

#### Fonte de Alimentação Dedicada — CanaKit (Oficial-equivalente)
- **Especificação:** 5V / 3.5A (USB-C, sem Power Delivery).
- **Marca:** CanaKit (Referência internacional para Raspberry Pi).
- **Cabo:** 18 AWG espesso, comprimento ~1,5 m (5 pés).
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

### Fonte Compatível Com Raspberry Pi4 Tipo C 5v 3a Botão U1002
- **Status:** Removida do sistema em 2026-01-15.
- Fonte genérica com histórico real de undervoltage em Pi 4 + SSD.
- Não é confiável para operação 24/7 com carga USB contínua (SSD + UPS).
- **Motivo:** Produto entregue com conector incompatível (Não era USB-C) e qualidade duvidosa para missão crítica.

### UPS (Nobreak) — Ragtech M2 1200VA / 840W (Senoidal Puro)
- **Status:** Devolução iniciada em 2026-01-17.
- **Motivo:** Incompatibilidade com Linux/NUT.
- **Diagnóstico:** O chipset Microchip (`04d8:000a`) utiliza um protocolo binário proprietário (resposta `0xca` para comandos padrão), impedindo o monitoramento aberto sem engenharia reversa instável.
