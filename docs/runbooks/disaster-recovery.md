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
