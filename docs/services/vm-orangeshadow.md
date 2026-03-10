# OrangeShadow (Bitcoin & Monero Node)

A VM `OrangeShadow` é o "banco" soberano da infraestrutura. Projetada para ser uma caixa-forte digital, operando com armazenamento dedicado e tráfego anonimizado.
    - O nó não guarda fundos, ele atua estritamente como um motor de validação matemática independente (Don't Trust, Verify).
* **Justificativa:** alto uso de i/o de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.

## Especificações Técnicas (Proxmox)
Implementação realizada em 18/02/2026 e atualizada pela última vez em 08/03/2026.

| Recurso | Configuração | Detalhes / Justificativa |
| :--- | :--- | :--- |
| **ID / Nome** | `107` / `OrangeShadow` | Start at boot: **Sim** (Ordem de Boot: 6). Delay: 600s. |
| **OS** | Debian 13 (Trixie) | Instalação "Minimal". Sem GUI. |
| **Kernel** | Linux 6.x - 2.6 Kernel | Guest Agent ativado. |
| **vCPU** | 4 Cores | Type: `host` (AES-NI vital para validação de blocos) (**Cgroups `cpuunits: 512`**). |
| **RAM** | 16 GB (Temporário - IBD) | Ballooning: `0`. Swapness reduzido para `10` via Sysctl. |
| **Disco 1 (Boot)** | 32 GB (SCSI 0) | Storage: `local-zfs`. Sistema Operacional e Logs. |
| **Disco 2 (Dados)** | 1.8 TB (SCSI 1) | **SATA Físico (Passthrough)**. Otimizações de barramento KVM: `aio=threads`, `iothread=1`, `discard=on`, `backup=0` (Proíbe snapshots do Proxmox neste volume). Throttling rígido aplicado: `mbps_wr=250`, `mbps_rd=400`. |
| **Rede** | `vmbr0` | **VLAN Tag: 30** (SERVER). IP: `10.10.30.20`. |
| **File System** | ext4 (`/opt/blockchain`) | Montado com `noatime` obrigatório no `/etc/fstab` para preservação de IOPS de leitura. |
| **BIOS** | OVMF (UEFI) | Machine: `q35`. |

## Provisionamento de Software (Supply Chain)
* **Regra de Ouro:** Softwares core (Bitcoin, Monero, Electrs) **não** são instalados via gerenciadores de pacotes padrão (`apt`), pois dependem de repositórios de terceiros sujeitos a comprometimento.
* **Método:** Download direto de binários pré-compilados das *releases* oficiais.
* **Validação:** Exige-se sempre a conferência do hash criptográfico (`sha256sum`) e, preferencialmente, a validação da assinatura PGP dos desenvolvedores antes da movimentação para `/usr/local/bin/`.

## Armazenamento e Filesystem
* **Estratégia:** Isolamento físico de dados.
* **Disco de Dados:** O SSD de 2TB foi formatado com `ext4` e otimização de espaço (`-m 0` para remover reserva de root).
* Um SSD separado protege o NVMe principal de desgaste e latência.
* **Cache DRAM (Obrigatório):** O SSD **deve** possuir DRAM Cache dedicada. Durante o IBD (Initial Block Download), o node realiza milhões de pequenas escritas aleatórias (IOPS) para indexar as UTXOs. SSDs "DRAM-less" saturam o buffer SLC rapidamente, fazendo a velocidade de sincronização cair para níveis de KB/s, transformando um processo de 2 dias em 2 semanas.
* **Montagem:** Via UUID no `/etc/fstab`.
* **Estrutura:**
    * `/opt/blockchain/bitcoin`: Dados do Bitcoin Core.
    * `/opt/blockchain/monero`: Dados do Monero Daemon.

## Privacidade e Rede (Tor-Only)
Esta VM atua como uma ilha escura na rede.
* **Tor Service:** Instalado e ativo.
* **Configuração de Produção:** O Bitcoin Core e o Monero usarão o Proxy SOCKS5 local (`127.0.0.1:9050`) operando estritamente via `onlynet=onion`.
* **Exceção de IBD (Initial Block Download):** Exclusivamente durante a sincronização inicial de blocos do zero, o nó tem permissão para operar em clearnet, pois a rede Tor não suporta a transferência de >700GB de dados sem quedas massivas de *timeout*.

## Estratégia de Backup (Zero Knowledge)
A infraestrutura assume que a nuvem (Backblaze B2) é insegura.
* **Escopo do Restic (Ansible Provisioned):** Apenas inteligência do sistema. Nenhuma chave privada é salva.
  * `/home/fajre/.bitcoin/bitcoin.conf` e `/etc/systemd/system/bitcoind.service`
  * `/home/fajre/.electrs/config.toml` e `/etc/systemd/system/electrs.service`
  * `/etc/tor/torrc` (Inteligência de roteamento)
  * `/home/fajre/.bitmonero/bitmonero.conf` e `/etc/systemd/system/monerod.service`
* **Exclusões Forçadas:** Todo o diretório `/opt/blockchain`. A blockchain é um dado público de >720GB que pode ser reconstruído do zero. Fazer backup disso gera custo excessivo e abre vetor para vazamento de banco de dados e eventuais resquícios de arquivos soltos.

## Observabilidade
* **Métricas:** Node Exporter instalado (Porta 9100).
* **Integração:** Prometheus configurado para raspar `10.10.30.20:9100`.

## System Tuning & Hardening Local
* **Firewall (UFW):** Ativado com política *Default Deny*. Apenas SSH (Porta 22) e Node Exporter (Porta 9100, estritamente a partir de `10.10.30.10`) são permitidos. Portas P2P (8333, 18080) permanecem fechadas pois a comunicação externa ocorre exclusivamente via Tor.
* **Gerenciamento de Memória:**
    * **Swap:** Arquivo de contingência de 2GB configurado no disco de boot (protegido por LUKS no host físico).
    * **Swappiness:** Reduzido de `60` (padrão) para `10` (`vm.swappiness=10`) para evitar paginação desnecessária e preservar a latência e vida útil do SSD.

## Parâmetros Operacionais e Limites (Cgroups)
Para evitar o colapso do sistema (OOM Killer) ou saturação da rede, os serviços operarão com limites estritos via Systemd. As fases de construção do nó devem ser feitas **sequencialmente**.

### Fase 1: Sincronização Inicial (IBD - Bitcoin) - **[CONCLUÍDO em 08/03/2026]**
*Duração: ~21 horas. Máquina provou estabilidade térmica e de I/O.*
*Executado com a VM dimensionada temporariamente para 16GB de RAM. Clearnet.*
* **`bitcoin.conf`:** * `dbcache=11000` (Consumo agressivo para evitar *thrashing* no SSD).
  * `blocksonly=1` (Ignora mempool).
  * `listen=0` (Modo parasita: retém 100% de I/O para si, não serve blocos a terceiros).
  * `disablewallet=1` (Modo cego).
* **Systemd (`bitcoind.service`):** * `MemoryMax=14G` (Garante 2GB de fôlego para o kernel).
  * `TimeoutStopSec=600` (10 minutos para flush seguro do DB; evita corrupção se o Host enviar sinal de desligamento via NUT).

### Fase 2: Transição Tor e Indexação de Endereços (Electrs) - **[CONCLUÍDO em 10/03/2026]**
*A indexação do histórico da blockchain (2009-2026) pelo Electrs (RocksDB) foi finalizada em cerca de 20 horas. Client Sparrow Wallet (Arch Linux) conectado com sucesso via `Private Electrum`.*
* **Bitcoin:**
  * Tráfego de saída forçado para o proxy SOCKS5 (`127.0.0.1:9050`) via `onlynet=onion`.
  * Criação automática de Hidden Service via interação nativa com a API do Tor (`discover=1`, `listenonion=1`). Endereço IP e DNS não expostos no GitHub para OPSEC máxima.
  * Cache (`dbcache`) estrangulado para `512` MB para poupar a RAM do sistema.
* **Electrs:**
  * Compilado do código-fonte (Rust) na versão `0.11.1`.
  * Indexação inicial massiva de I/O no disco SATA de Passthrough (Diretório `/opt/blockchain/electrs`).
  * Serviço de backend: `MemoryMax=10G` (Garante margem térmica de RAM para o host).
  * Conexão LAN na porta `TCP 50001` isolada pelo UFW para permitir apenas tráfego interno das VLANs do Homelab (`10.10.0.0/16`).

### Fase 3: Sincronização Inicial (IBD - Monero)
*Bitcoin e Electrs operam em background (já sincronizados).*
* **Bitcoin:** Systemd `MemoryMax=2G`.
* **Monero:** Sincronização nativa rápida via LMDB. Systemd: `MemoryMax=10G`.

### Fase 4: Produção 24/7 (Soberania Total)
*Executado com a VM reduzida para seu tamanho final de 8GB de RAM. Operação 100% Tor (`onlynet=onion`).*
* **Bitcoin:** `dbcache=512`, `listen=1`, Systemd: `MemoryMax=3G`.
* **Electrs:** Ativo como ponte para a carteira externa.
* **Monero:** `--out-peers=16`, `--in-peers=16`, Systemd: `MemoryMax=3G`.
* **Reserva de Sistema:** ~1.5GB garantidos para o SO, Node Exporter e Tor Daemon.
