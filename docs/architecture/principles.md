## Princípios de Operação

* **Backups com estratégia 3-2-1:**
    * **(3) Três Cópias:** Dados de produção no ZFS + 2 cópias de backup.
    * **(2) Duas Mídias:** Cópia 1 no pool ZFS (produção) e Cópia 2 (backup local, ex: HD externo ou outro pool).
    * **(1) Uma Cópia Off-site:** A cópia de backup será automatizada pelo **Restic** (rodando no `LXC de Gerenciamento`) e enviada de forma criptografada para um *bucket* **Backblaze B2** (S3-compatível).
    * **Exceção de Economia:** A pasta de dados da Blockchain do Bitcoin (`blocks/chainstate`) será **excluída** do backup off-site para economizar custos de armazenamento e banda, pois pode ser baixada novamente da rede P2P. Apenas arquivos de configuração e carteiras (`wallet.dat`) serão backupeados.
    * Backup de Configuração do Host ("Casca"): O PBS faz backup das VMs, mas não do Host Proxmox.
		- Script Semanal: Exporta arquivos críticos de texto (/etc/network/interfaces, /etc/pve/user.cfg, /etc/hosts, regras de firewall do cluster) para o repositório Git privado (Forgejo).
		- Objetivo: Permitir a reconstrução de um "Bare Metal" em minutos caso o SSD de boot queime, sem precisar redescobrir quais VLANs estavam em quais bridges.
* **Docs-as-Code/Living Documentation (Runbooks):** A documentação da infraestrutura, procedimentos de recuperação e diagramas viverão em repositório Git, sendo mantidos em **sincronia automática** entre o **GitHub** (Visibilidade/Portfólio) e o **Forgejo** (Cópia Local/Soberania), junto com os scripts Terraform/Ansible.
* **Snapshots de VM (Proteção contra Updates):** A VM `DockerHost` (que centraliza serviços críticos) terá snapshots automáticos configurados no Proxmox (retenção: últimos 3 dias) para permitir rollback instantâneo em caso de falha catastrófica após atualizações do Debian ou Docker.

* **Regra Crítica Bitcoin (Backup Atômico):**
    * **O Problema:** Copiar o arquivo `wallet.dat` enquanto o Bitcoin roda corrompe o banco de dados (Berkeley DB).
    * **A Solução:** Um script customizado (`backup-bitcoin.sh`) rodará diariamente via Cronjob. Ele executa o comando RPC **`bitcoin-cli backupwallet`**, que força o software a "congelar" o estado e exportar um snapshot seguro e íntegro para o **pool ZFS (NVMe)**.
    * **Fluxo de Dados:** SSD SATA (Live) -> API Bitcoin Core -> Arquivo Dump no NVMe (Snapshot) -> Restic (Nuvem).
