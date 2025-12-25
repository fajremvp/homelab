# O Servidor

## Processador — Intel Core i5-12400

### Identificação
- Fabricante: Intel  
- Modelo: Core i5-12400  
- SKU: BX8071512400  

### Arquitetura e Soquete
- Microarquitetura: Alder Lake  
- Soquete: LGA1700  
- Chipsets compatíveis: Intel Série 600  
- Multiplicador desbloqueado: Não  

### Núcleos, Threads e Cache
- Núcleos: 6 (6 P-cores, 0 E-cores)  
- Threads: 12  
- Cache L3: 18 MB  
- Cache L2 total: 7,5 MB  

### Frequências
- Clock base: 2,5 GHz  
- Turbo máximo: até 4,4 GHz  

### Memória
- Controlador de memória integrado  
- Canais: 2  
- Capacidade máxima: 128 GB  
- Tipos suportados: DDR4-3200, DDR5-4800  

### PCI Express
- PCIe 5.0: 16 pistas (direto da CPU)  
- PCIe 4.0: 4 pistas (direto da CPU)  

### Gráficos Integrados
- iGPU: Intel UHD Graphics 730  

### Energia e Térmica
- Potência base (PBP): 65 W  
- Potência turbo máxima (MTP): 117 W  

### Recursos e Tecnologias
- Intel Standard Manageability (ISM)

## Cooler — DeepCool AK400

### Identificação
- Fabricante: DeepCool  
- Modelo: AK400  
- Part number: R-AK400-BKNNMN-G-1  

### Compatibilidade de Soquete
- Intel: LGA1700, LGA1200, LGA115x  
- AMD: AM4, AM5  

### Projeto Térmico
- Tipo: Air cooler, torre única  
- Heatpipes: 4 × 6 mm (contato direto)  

### Ventoinha
- Tamanho: 120 mm  
- Rotação: 500–1850 RPM (PWM)  
- Fluxo de ar: 66,47 CFM  
- Pressão estática: 2,04 mmH₂O  
- Ruído máximo: ≤ 29 dBA  
- Rolamento: Fluid Dynamic Bearing (FDB)  

### Características Elétricas
- Tensão: 12 V DC  
- Corrente: 0,13 A  
- Potência: 1,56 W  

### Justificativa Técnica
- Redução significativa de ruído em relação ao cooler box Intel.  
- Capacidade térmica adequada para operação contínua (24/7) com folga térmica.


## Placa-mãe — Gigabyte B760M GAMING AC

### Identificação
- Fabricante: Gigabyte  
- Modelo: B760M GAMING AC  
- Chipset: Intel B760  

### CPU e Soquete
- Soquete: LGA1700  
- Suporte a CPUs Intel Core 12ª / 13ª / 14ª geração  
- Suporte a Intel Pentium Gold e Celeron  

### VRM e Alimentação
- Topologia VRM: 6 + 2 + 1 fases  
- Conector de energia CPU: 8 pinos  
- Adequado para operação contínua (24/7) em CPUs não destravadas  

### Memória
- Tipo: DDR4  
- Slots: 2 × DIMM  
- Arquitetura: Dual Channel  
- Capacidade máxima: 64 GB  
- Velocidade suportada: até DDR4-5333 (OC)  
- Suporte a XMP  
- ECC: não (UDIMM non-ECC)  

### Slots de Expansão
- 1 × PCIe 4.0 x16 (ligado à CPU)  
- 1 × PCIe 3.0 x1 (ligado ao chipset)  

### Armazenamento
- 1 × M.2 PCIe 4.0 x4 (CPU)  
- 1 × M.2 PCIe 4.0 x4 (Chipset)  
- 4 × SATA III (6 Gb/s)  
- RAID SATA: 0 / 1 / 5 / 10  

### Gráficos Onboard (via iGPU da CPU)
- Saídas: HDMI, DisplayPort, D-Sub  
- Máx.:  
  - HDMI: até 4K @ 60 Hz  
  - DisplayPort: até 4K @ 60 Hz  
- Suporte a até 3 monitores simultâneos  

### Rede
- Ethernet: Realtek 2.5 GbE  

### Comunicação Sem Fio
- Wi-Fi: 802.11ac (dependente da revisão da placa)  
- Bluetooth: 5.0 / 5.1 (dependente da revisão da placa)  

### USB (principais)
- 1 × USB-C 3.2 Gen 1 (traseiro)  
- 5 × USB 3.2 Gen 1  
- 6 × USB 2.0 (traseiros + headers)  

### Áudio
- Codec: Realtek HD Audio  
- Canais: até 7.1  

### BIOS e Firmware
- UEFI AMI  
- Flash ROM: 128 Mbit  
- Q-Flash Plus (atualização sem CPU/RAM/GPU)  

### Fator de Forma
- Micro-ATX (24,4 × 22,5 cm)  

### Justificativa Técnica
- VRM suficiente para carga contínua em ambiente de servidor doméstico.  
- Suporte nativo a 2 × NVMe PCIe 4.0 (ex.: ZFS mirror) + 4 × SATA.
- Rede 2.5 GbE integrada, eliminando necessidade de NIC adicional.

## Memória RAM — Kingston Fury Beast DDR4 (2 × 32 GB)

### Identificação
- Fabricante: Kingston  
- Linha: Fury Beast  
- Part number: KF432C16BB/32  

### Configuração
- Quantidade: 2 módulos  
- Capacidade total: 64 GB  
- Arquitetura: Dual Channel  

### Especificações Técnicas
- Tipo: DDR4 UDIMM  
- Frequência: 3200 MT/s  
- Latência: CL16  
- Tensão: 1,35 V  
- Capacidade por módulo: 32 GB  
- ECC: Não (non-ECC)  
- Perfil: Intel XMP  

### Ambiente de Operação
- Temperatura operacional: 0 °C a 85 °C  

### Justificativa Técnica
- Capacidade dimensionada para ZFS ARC, múltiplas VMs e workloads contínuos sem swap.  
- Mantém margem para expansão futura até 128 GB (limite da plataforma).

### Ajustes de Software (ZFS ARC)
- ARC mínimo: 8 GB  
- ARC máximo: 16 GB  
- Objetivo: equilíbrio entre cache de disco e disponibilidade de RAM para VMs pesadas (Bitcoin node / Kubernetes).

---

## Armazenamento (Sistema / VMs) — Kingston Fury Renegade NVMe (2 × 1 TB)

### Configuração
- Topologia: ZFS Mirror (RAID 1)  
- Uso: SO (Proxmox VE ZFS Root), VMs e Containers  

### Identificação
- Fabricante: Kingston  
- Modelo: Fury Renegade  
- Part number: SFYRSK/1000G  

### Especificações Técnicas
- Capacidade: 1 TB (cada)  
- Fator de forma: M.2 2280  
- Interface: PCIe 4.0 x4 (NVMe)  
- Controlador: Phison E18  
- NAND: 3D TLC  
- DRAM Cache: Sim  

### Desempenho
- Leitura sequencial: até 7300 MB/s  
- Gravação sequencial: até 6000 MB/s  
- IOPS 4K (leitura / gravação): até 900k / 1M  

### Durabilidade
- TBW: 1,0 PB  
- MTBF: 1.800.000 h  

### Consumo de Energia
- Idle: ~5 mW  
- Médio: ~0,33 W  
- Pico leitura: ~2,8 W  
- Pico gravação: ~6,3 W  

### Estratégia de Criptografia (FDE) e Otimização
- Método: conversão pós-instalação (ZFS Mirror → LUKS → ZFS Replace)  
- Criptografia: LUKS2 (AES-XTS-Plain64, chave efetiva 512-bit)  
- Alinhamento de setor: 4096 bytes (NVMe)  
- TRIM: habilitado (`discard`)  

### Otimizações dm-crypt (crypttab)
- `perf-no_read_workqueue`  
- `perf-no_write_workqueue`  

### Modelo de Ameaça e Impacto
- Protege contra: acesso físico não autorizado (discos em repouso).  
- Não protege contra: extração de chaves em RAM com o sistema ligado (cold boot).  
- Overhead estimado:
  - CPU (AES-NI): ~2–5%  
  - Throughput sequencial: ~10–30% (mitigado pelas flags de performance)  
  - Vida útil do SSD: impacto desprezível com TRIM ativo.

## Armazenamento (Bitcoin) — Samsung 870 EVO 2 TB

### Função e Arquitetura
- Uso exclusivo: blockchain do Bitcoin (I/O intenso e contínuo)
- Isolamento físico do workload para separar desgaste (TBW) do sistema e VMs
- Camada lógica: LVM-Thin

### Identificação
- Fabricante: Samsung
- Modelo: 870 EVO
- Part number: MZ-77E2T0B/AM

### Especificações Técnicas
- Capacidade: 2 TB
- Interface: SATA III (6 Gb/s)
- Fator de forma: 2.5"
- Controlador: Samsung MKX
- Cache DRAM: **Sim (2GB LPDDR4)**
- Leitura sequencial: até 560 MB/s
- Gravação sequencial: até 530 MB/s

### Justificativa Técnica
- **Cache DRAM Dedicado:** Diferencial crítico em relação a modelos de entrada (como SanDisk Plus). Permite sustentar a alta taxa de IOPS necessária durante o IBD (Initial Block Download) sem engasgar o controlador.
- **Durabilidade:** Controlador robusto para cargas de escrita sustentada.
- **Segurança:** Será criptografado via LUKS2 (keyfile dependente do root) para proteção de dados em repouso.

## Fonte (PSU) — MSI MAG A750GL PCIE5

### Identificação
- Fabricante: MSI  
- Modelo: MAG A750GL PCIE5  

### Especificações Elétricas
- Formato: ATX  
- Potência nominal: 750 W  
- Eficiência: 80 PLUS Gold  
- PFC: ativo  
- Tensão de entrada: 100–240 V AC  
- Frequência: 47–63 Hz  

### Design e Topologia
- Modularidade: totalmente modular  
- Capacitores: japoneses (alta durabilidade)  
- Ventoinha: 120 mm, Fluid Dynamic Bearing (FDB)  

### Proteções Elétricas
- OCP (sobre-corrente)  
- OVP (sobre-tensão)  
- UVP (sub-tensão)  
- OPP (sobre-potência)  
- OTP (sobre-temperatura)  
- SCP (curto-circuito)  

### Justificativa Técnica
- Margem elétrica ampla para carga contínua 24/7 com baixo estresse térmico.  
- Alta eficiência reduz consumo e calor dissipado.  
- Conjunto completo de proteções para estabilidade e longevidade do servidor.

  ## Gabinete — DeepCool CC560 (Branco)

### Identificação
- Fabricante: DeepCool  
- Modelo: CC560  
- Part number: R-CC560-WHGAA4-G-2  

### Formato e Compatibilidade
- Tipo: Mid Tower  
- Placas-mãe suportadas: Mini-ITX, Micro-ATX, ATX  

### Dimensões
- 416 × 210 × 477 mm (C × L × A)  

### Ventilação
- Fans pré-instalados:
  - Frontal: 3 × 120 mm  
  - Traseiro: 1 × 120 mm  
- Suporte máximo de fans:
  - Frontal: até 3 × 120 mm ou 2 × 140 mm  
  - Superior: até 2 × 120 mm ou 2 × 140 mm  
  - Traseiro: 1 × 120 mm  

### Suporte a Radiadores
- Frontal: até 360 mm  
- Superior: até 240 mm  
- Traseiro: 120 mm  

### Armazenamento
- Baias:  
  - 2 × 3.5"  
  - 2 × 2.5"  

### Slots e Limites Físicos
- Slots de expansão: 7  
- Altura máxima do cooler da CPU: 163 mm  
- Comprimento máximo da GPU: 370 mm  
- Fonte suportada: ATX (até 170 mm)  

### Painel Frontal (I/O)
- 1 × USB 3.0  
- 1 × USB 2.0  
- 1 × Áudio  

### Justificativa Técnica
- Fluxo de ar adequado para operação contínua com múltiplos discos e NVMe.  
- Ventoinhas inclusas reduzem necessidade de upgrades imediatos.  
- Nível de ruído compatível com ambiente doméstico.

#### Teste de Instalação e Rede (Dry Run)

* **Data:** 20/12/2025
* **Objetivo:** Validar detecção de hardware (NICs HP e Realtek), estabilidade do ZFS Mirror e VT-x antes da criptografia.
* **Resultado:** **SUCESSO**.
    * **Rede:** Interface Onboard (`eno1`/`r8169`) identificada corretamente como `nic1` no Proxmox. Placa HP Quad-Port (`e1000e`) identificada como `nic0, 2, 3, 4`.
    * **Conectividade:** Latência de `0.2ms` em link direto Gigabit.
    * **Discos:** ZFS Mirror (`rpool`) montado e ativo.
    * **Bloqueios Superados:** Ajuste de regra de saída/entrada no Firewall do cliente (Arch Linux) necessário para pingar o servidor na sub-rede `10.10.10.x` sem roteador.

## [LEGADO] Placa de Rede Extra (NIC) — HP NC364T (Removida)

> **STATUS:** Removida do sistema em 2025-12-22.
> **MOTIVO:** Incompatibilidade com drivers modernos no Proxmox/Debian e redundância técnica após a implementação de VLAN Trunking no Switch Gerenciável.

### Função Anterior
- Interface dedicada para WAN do OPNsense.

### Especificações Técnicas
- Fabricante: HP  
- Modelo: NC364T  
- Chipset: Intel 82571EB  
- Portas: 4 × Gigabit Ethernet.

### Lições Aprendidas
- Hardware de servidor antigo pode causar conflitos de IRQ e instabilidade em placas-mãe de consumidor modernas (LGA1700). 
- A virtualização de rede (VLANs) é mais eficiente e consome menos energia do que múltiplas placas físicas para tráfego gigabit doméstico.
