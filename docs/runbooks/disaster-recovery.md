## Estratégia de Recuperação de Desastres (DR Drills)

* **Princípio:** "Backup não testado é apenas esperança."
* **Periodicidade:**
    * **Mensal (Automático):** Script sobe uma VM temporária, restaura o backup do banco de dados do Vaultwarden e verifica se retorna HTTP 200.
    * **Semestral (Manual):** "Chaos Monkey Day". Desligar o host abruptamente (simular queda de energia) e cronometrar o tempo de recuperação total (RTO) a partir do zero (Cold Start).
* **Critério de Sucesso:**
    1.  O serviço sobe e responde a requisições.
    2.  Dados íntegros (checksum bate com a origem).
    3.  Sem perda de dados críticos (RPO < 24h).

* **Troca de Disco Físico (ZFS + LUKS):**
   - **Guia de Referência:** [ZFS replace root disk on LUKS](https://github.com/mr-manuel/proxmox/blob/main/zfs-replace-root-disk/README.md).
   - **Atenção Crítica:** NÃO usar o comando `zpool replace` direto no dispositivo físico novo (`/dev/nvmeX`).
   - **Protocolo Obrigatório:**
      1. Copiar tabela de partição do disco saudável (`sgdisk`).
      2. Formatar a partição de dados do disco novo com LUKS (`cryptsetup luksFormat`) usando os mesmos parâmetros de otimização (4k, aes-xts).
      3. Abrir o volume LUKS novo.
      4. Executar `zpool replace rpool disco-velho /dev/mapper/luks-novo`.

## Recuperação de Dados (Backup Restore)
Implementado em: 2026-01-09.

Utilizar **Restic** com backend **Backblaze B2**. Cada host (DockerHost, Vault, etc.) deve possuir seu próprio repositório isolado e criptografado.

### Procedimento de Restore (Arquivo Único)
Utilizar quando um arquivo de configuração for deletado acidentalmente.

1.  **Acessar o Host** via SSH (ex: `ssh fajre@10.10.30.10`).
2.  **Carregar as credenciais:**
    ```bash
    source /etc/restic-env.sh
    # (Se for Alpine, utilizar '. /etc/restic-env.sh')
    ```
3.  **Listar os snapshots disponíveis:**
    ```bash
    restic snapshots
    ```
4.  **Copiar o ID do snapshot desejado** (ex: `a1b2c3d4`).
5.  **Executar o Restore:**
    ```bash
    # Sintaxe: restic restore <SNAPSHOT_ID> --target / --include <CAMINHO_COMPLETO_DO_ARQUIVO>
    restic restore a1b2c3d4 --target / --include /opt/services/whoami/docker-compose.yml
    ```
6.  **Validar:** Verificar se o arquivo voltou ao local original com `ls -l`.

### Procedimento de Restore (Total / Disaster)
Utilizar quando o servidor for formatado e reinstalado do zero.

1.  **Atender aos Pré-requisitos:** Instalar o Restic e recriar o arquivo `/etc/restic-env.sh` com as chaves do B2 e a senha do repositório (guardadas no Vaultwarden).
2.  **Executar o Restore Total:**
    ```bash
    source /etc/restic-env.sh
    restic restore latest --target /
    ```
3.  **Realizar o Pós-Restore:** Reiniciar os serviços ou o servidor para carregar as configurações restauradas.

### Recuperação do Firewall (OPNsense)
O OPNsense não utilizar Restic. Ele utilizar o plugin `os-git-backup`.

1.  **Reinstalar** o OPNsense.
2.  **Instalar** o plugin `os-git-backup`.
3.  **Configurar** o repositório Git (`ssh://github.com/...`) e a chave SSH RSA.
4.  **Aguardar** o plugin baixar o `config.xml` mais recente e aplicar automaticamente.
