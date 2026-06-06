## Princípios de Operação

* **Backups com estratégia 3-2-1:**
    * **(3) Três Cópias:** Dados de produção no ZFS + 2 cópias de backup.
    * **(2) Duas Mídias:** Cópia 1 no pool NVMe ZFS (produção) e Cópia 2 no HD SATA Magnético (WD Blue de 1TB no NixOS, criptografado com LUKS2, atuando como mídia de checkpoint discreto local).
    * **(1) Uma Cópia Off-site:** A cópia de backup contínua automatizada pelo **Restic** (rodando no `LXC de Gerenciamento`) enviada de forma criptografada para o **Backblaze B2**.
    * **Kit de Bootstrap (Redução de RTO vs RPO):** O Restic (B2) atua como fonte primária, versionada e imutável da infraestrutura na nuvem (RPO longo). Em paralelo, o script manual `scripts/dr-checkpoint.sh` extrai a "Casca" do Hypervisor (configs core do Proxmox) e as imagens VZDump das VMs para o HD local. O objetivo é acelerar a fase de *Bare Metal Restore* em um cenário de destruição física, operando sob demanda e 100% Air-Gapped.
    * **Exceção de Economia:** A pasta de dados da Blockchain do Bitcoin (`blocks/chainstate`) será **excluída** da nuvem para economizar custos. Ela fica restrita ao disco em passthrough e pode ser baixada novamente da rede P2P. Apenas arquivos de configuração (`bitcoin.conf`, `torrc`) são backupeados.

* **Backups com estratégia 3-2-1-1-0:**
    * **(3) Três Cópias:** Dados de produção no ZFS + 2 cópias de backup.
    * **(2) Duas Mídias:** Cópia 1 no pool NVMe ZFS (produção) e Cópia 2 no HD SATA Magnético (WD Blue de 1TB no NixOS, criptografado com LUKS2).
    * **(1) Uma Cópia Off-site:** A cópia de backup contínua automatizada pelo **Restic** (rodando no `LXC de Gerenciamento`) enviada de forma criptografada para o **Backblaze B2**.
    * **(1) Uma Cópia Offline/Air-Gapped:** A cópia local atua como checkpoint discreto extraído via script manual (`scripts/dr-checkpoint.sh`), permanecendo isolada de forma lógica/física do servidor principal.
    * **(0) Zero Erros (Testado):** Integridade de dados garantida matematicamente (`restic check` e ZFS scrubs) e testes periódicos de Bare Metal Restore documentados em Runbook.
    * **Kit de Bootstrap (Redução de RTO vs RPO):** O Restic (B2) atua como fonte primária, versionada e imutável da infraestrutura na nuvem (RPO longo). Em paralelo, o script manual extrai a "Casca" do Hypervisor (configs core do Proxmox) e as imagens VZDump das VMs para o HD local. O objetivo é acelerar a fase de *Bare Metal Restore* em um cenário de destruição física, operando sob demanda e 100% Air-Gapped.
    * **Exceção de Economia:** A pasta de dados da Blockchain do Bitcoin (`blocks/chainstate`) será **excluída** da nuvem para economizar custos. Ela fica restrita ao disco em passthrough e pode ser baixada novamente da rede P2P. Apenas arquivos de configuração (`bitcoin.conf`, `torrc`) são backupeados.

* **Docs-as-Code/Living Documentation (Runbooks):** A documentação da infraestrutura, procedimentos de recuperação e diagramas viverão em repositório Git, sendo mantidos em **sincronia automática** entre o **GitHub** (Visibilidade/Portfólio) e o **Codeberg** (Backup), junto com os scripts Terraform/Ansible.
* **Snapshots de VM (Proteção contra Updates):** A VM `DockerHost` (que centraliza serviços críticos) terá snapshots automáticos configurados no Proxmox (retenção: últimos 3 dias) para permitir rollback instantâneo em caso de falha catastrófica após atualizações do Debian ou Docker.

* **Regra Crítica Bitcoin (Backup Atômico):**
    * **O Problema:** Copiar o arquivo `wallet.dat` enquanto o Bitcoin roda corrompe o banco de dados (Berkeley DB).
    * **A Solução:** Um script customizado (`backup-bitcoin.sh`) rodará diariamente via Cronjob. Ele executa o comando RPC **`bitcoin-cli backupwallet`**, que força o software a "congelar" o estado e exportar um snapshot seguro e íntegro para o **pool ZFS (NVMe)**.
    * **Fluxo de Dados:** SSD SATA (Live) -> API Bitcoin Core -> Arquivo Dump no NVMe (Snapshot) -> Restic (Nuvem).

* **Shift-Left Security & Qualidade Contínua:**
    * **Filosofia:** A segurança e a qualidade do código devem ser verificadas **antes** do commit, não depois do deploy. Erros detectados na máquina do desenvolvedor custam zero; erros em produção custam downtime ou vazamento de dados.
    * **Mecanismo:** Uso obrigatório de **Pre-Commit Hooks** (Git Hooks). O commit é bloqueado localmente se:
        - Houver segredos/chaves expostas (Gitleaks).
        - A sintaxe YAML estiver inválida ou fora do padrão (Yamllint).
        - Os playbooks do Ansible ferirem boas práticas ou idempotência (Ansible-Lint).
        - Scripts Shell tiverem bugs lógicos (ShellCheck).
