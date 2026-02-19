# OrangeShadow (Bitcoin & Monero Node)

A VM `OrangeShadow` é o "banco" soberano da infraestrutura. Projetada para ser uma caixa-forte digital, operando com armazenamento dedicado e tráfego anonimizado.
* **Justificativa:** alto uso de i/o de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.

## Especificações Técnicas (Proxmox)
Implementação realizada em: 18/02/2026.

| Recurso | Configuração | Detalhes / Justificativa |
| :--- | :--- | :--- |
| **ID / Nome** | `107` / `OrangeShadow` | Start at boot: **Sim** (Atraso configurado). |
| **OS** | Debian 13 (Trixie) | Instalação "Minimal". Sem GUI. |
| **Kernel** | Linux 6.x - 2.6 Kernel | Guest Agent ativado. |
| **vCPU** | 4 Cores | Type: `host` (AES-NI vital para validação de blocos). |
| **RAM** | 8 GB | Ballooning: `0` (Desativado para garantir estabilidade do cache DB). |
| **Disco 1 (Boot)** | 32 GB (SCSI 0) | Storage: `local-zfs`. Sistema Operacional e Logs. |
| **Disco 2 (Blockchain)** | **Passthrough Físico** | SSD Samsung 870 EVO (2TB). Montado em `/opt/blockchain`. |
| **Rede** | `vmbr0` | **VLAN Tag: 30** (SERVER). IP: `10.10.30.20`. |
| **BIOS** | OVMF (UEFI) | Machine: `q35`. |

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
Esta VM não deve vazar o IP residencial público em hipótese alguma.
* **Tor Service:** Instalado e ativo.
* **Configuração:** O Bitcoin Core e o Monero devem ser configurados para usar o Proxy SOCKS5 local (`127.0.0.1:9050`).

## Estratégia de Backup
Diferente das outras VMs, não fazemos backup de "tudo". A Blockchain (~1TB) é descartável (pode ser baixada novamente). O que importa são as chaves privadas (`wallet.dat`).

* **Ferramenta:** Restic (via script `/usr/local/bin/backup-daily.sh`).
* **Repositório:** `b2:homelab-backup-fajre:/orangeshadow` (Bucket Dedicado).
* **Lógica do Script:**
    1. Verifica se as pastas existem.
    2. Faz backup **apenas** de:
        - `wallet.dat`
        - `bitcoin.conf` / `bitmonero.conf`
        - Chaves de assinatura (se houver).
    3. **Exclui explicitamente:** `blocks/`, `chainstate/`, `data.mdb` (Monero Blockchain).
* **Automação:** Provisionado via Ansible (`setup_backup.yml`).

## Observabilidade
* **Métricas:** Node Exporter instalado (Porta 9100).
* **Integração:** Prometheus configurado para raspar `10.10.30.20:9100`.
