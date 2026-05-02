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

## Acesso de Emergência (Out-of-Band)

Utilizar em caso o servidor estar travado na tela de senha (LUKS) e eu estiver fora da rede local.

### Pré-requisitos
1.  **Meu celular ou Arch** com cliente Tailscale instalado e autenticado.
2.  **Chave Privada SSH** (Ed25519) carregada no dispositivo cliente.

### Procedimento de Desbloqueio (Via Android/Celular)
1.  **Desativar outras VPNs:** O Android não suporta VPNs simultâneas (ex: desligue o ProtonVPN).
2.  **Ativar Tailscale:** Conectar à malha VPN.
3.  **Acessar Shell:** Abrir o Termux ou cliente SSH.
4.  **Conectar:**
    ```bash
    ssh root@192.168.1.200 -p 2222
    ```
5.  **Desbloquear:** Digitar `cryptroot-unlock` e inserir a passphrase do disco.
6.  **Encerrar:** Assim que o comando retornar sucesso, desconecte o Tailscale e reative sua VPN de privacidade.

### Procedimento no Arch Linux (Client) & Troubleshooting DNS

#### Conectar
O comando deve aceitar explicitamente as rotas anunciadas pelo RPi.
**AVISO:** NUNCA executar este comando se estiver fisicamente conectado à mesma rede Wi-Fi/Cabo que o servidor. Isso causa loop de roteamento. Usar apenas via 5G ou redes externas.
```bash
sudo tailscale up --accept-routes
```
#### Desconectar e Corrigir DNS
- Ao desconectar, o `systemd-resolved` pode falhar ao restaurar o DNS original, deixando o sistema sem navegação.
1. **Desconectar:**
   ```bash
   sudo tailscale down
   ```
2. **Validar conectividade:**
   ```bash
   ping google.com
   ```
3. **Se falhar (Name Resolution Error):** Forçar o NetworkManager a renovar o DHCP e a tabela DNS:
   ```bash
   sudo systemctl restart NetworkManager
   ```
### Janela de Acesso
- A porta 2222 (Dropbear) só existe durante a fase de initramfs. Após o início do boot do Proxmox, a conexão será recusada (Connection Refused). Isso é o comportamento esperado.

## Arquitetura de FSD (Forced Shutdown) - Apagão Elétrico

O sistema é protegido contra corrupção do ZFS por um Nobreak Intelbras (1000VA) gerenciado por uma arquitetura Master/Slave via NUT.

* **Primary (RPi - 192.168.1.5):** Comunica-se fisicamente com o UPS via USB. Ao atingir 50% de bateria, ele dispara o sinal FSD na rede.
* **Secondary (Proxmox - 192.168.1.200):** Ouve o RPi. Ao receber FSD, inicia o shutdown de todas as VMs na ordem correta e exporta o ZFS pool (Tempo real medido: ~83s).
* **Delay Incondicional:** Para contornar a desconexão prematura do TCP causada pelo `systemd` no Proxmox, o RPi possui um interceptador (`/usr/local/bin/ups-kill.sh`) que impõe um **sleep de 130 segundos**. O RPi aguarda esse tempo no escuro antes de comandar o corte mecânico (relé) do Nobreak.

### Teste Seguro de Apagão (Risco Zero para ZFS)

A cada 6 meses, o tempo de shutdown do Proxmox deve ser revalidado (ou após adicionar VMs pesadas como Bitcoin Core).

1. Mova o cabo de força do Proxmox para uma tomada normal da parede (isolando-o do Nobreak).
2. Puxe o cabo do Nobreak da tomada (ativando a bateria apenas para o RPi/Switch/AP/Modem).
3. No terminal do RPi, execute: `sudo upsmon -c fsd`.
4. **Cronometre:** Verifique o tempo exato (Tempo A) que o Proxmox leva para desligar e o momento (Tempo B) em que o Nobreak dá o estalo do relé e apaga o RPi/Switch.
5. Se `Tempo B` for MAIOR que `Tempo A`, a matemática está segura. Recoloque o cabo do Proxmox no UPS.
6. Se `Tempo A` (Proxmox) ultrapassar o `Tempo B`, **cancele operações, ligue o Proxmox na energia** e recalcule o `sleep` no script do RPi.

## Validação do DNS Secundário (RPi - AdGuard Home)

Procedimento para verificar periodicamente o funcionamento, privacidade e failover do DNS secundário em `192.168.1.5`.

### Pré-requisito
O LXC AdGuard-Primary (101) deve estar rodando normalmente antes de iniciar. Ao final, verificar se foi religado.

### 1. Verificar serviço e tmpfs

```bash
ssh fajre@192.168.1.5

sudo systemctl status AdGuardHome
# Esperado: active (running)

sudo journalctl -u AdGuardHome --no-pager | wc -l
# Esperado: 1 (apenas a linha de start)

mount | grep AdGuardHome
# Esperado: tmpfs on /opt/AdGuardHome/data type tmpfs (rw,relatime,size=131072k,mode=700)

sudo ls -la /opt/AdGuardHome/ | grep data
# Esperado: drwx------ (modo 0700, root)
```

### 2. Verificar configuração de privacidade

```bash
sudo grep -A5 'querylog' /opt/AdGuardHome/AdGuardHome.yaml
# Esperado: enabled: false

sudo grep -A3 'statistics' /opt/AdGuardHome/AdGuardHome.yaml
# Esperado: enabled: false (ou ausente)
```

### 3. Verificar DNS e filtragem

```bash
# Do Arch Linux:
dig @192.168.1.5 google.com
# Esperado: status: NOERROR, resposta válida

dig @192.168.1.5 doubleclick.net
# Esperado: 127.0.0.1 (bloqueado pela lista OISD)
```

### 4. Testar failover (com flush obrigatório)

> ⚠️ **CRÍTICO:** Sempre executar `resolvectl flush-caches` antes de testar. Sem isso, o `systemd-resolved` pode retornar resultado do cache do primário, gerando um **falso positivo**.

```bash
# 1. Derrubar o primário (via GUI Proxmox ou CLI)
# pvesh create /nodes/homelab/lxc/101/status/stop  (no host Proxmox)

# 2. Limpar o cache DNS do Arch
sudo resolvectl flush-caches

# 3. Testar resolução - deve usar o secundário automaticamente
resolvectl query github.com
# Esperado: resposta válida via enp1s0f1, sem erro

# 4. Confirmar via dig direto no secundário
dig @192.168.1.5 github.com
# Esperado: NOERROR

# 5. Religar o primário
# pvesh create /nodes/homelab/lxc/101/status/start
```

### 5. Validar amnésia no reboot físico

```bash
# No RPi, verificar estado antes:
sudo ls -la /opt/AdGuardHome/data/
# Anotar tamanho do stats.db

# Reboot:
sudo reboot

# Após o boot, verificar:
sudo ls -la /opt/AdGuardHome/data/
# Esperado: stats.db = 16384 bytes (vazio/zerado), timestamps recriados
# Confirma que nenhum histórico de queries sobreviveu ao reboot
```

> **Nota arquitetural:** O restart do serviço (`systemctl restart AdGuardHome`) **não** apaga o tmpfs - apenas o reboot físico do hardware o faz. Isso é comportamento correto e esperado. A amnésia só é total com a perda de energia ou reboot do RPi.
