# HashiCorp Vault (Gestor de Segredos)

Servidor central de segredos da infraestrutura. Roda isolado em uma VM dedicada para garantir "Defense in Depth".

## Especificações Técnicas
Implementação realizada em: 2026-01-04.

| Recurso | Configuração | Justificativa |
| :--- | :--- | :--- |
| **ID / Hostname** | `106` / `vault` | Start at boot: **Sim** (Prioridade 3). |
| **OS** | Debian 13 (Trixie) | Instalação "Minimal". Sem Docker. |
| **vCPU** | 2 Cores | Type: `host` (AES-NI para criptografia rápida). |
| **RAM** | 2 GB | Suficiente para o binário Go e cache do Raft. |
| **Disco** | 32 GB (SCSI) | Storage: `local-zfs` (SSD). IO Thread On. |
| **Rede** | `10.10.40.10` | **VLAN 40 (SECURE)**. Gateway: `10.10.40.1`. |

## Arquitetura de Segurança (Hardening)

### 1. Isolamento de Rede (Zero Trust)
* **Internet:** Bloqueada por padrão no OPNsense. A VM não consegue iniciar conexões para fora (Regra `Temp Install Vault` desativada).
* **Ingress (Entrada):**
    * Todo tráfego é **bloqueado** exceto portas explicitamente liberadas.
    * **Porta 8200 (API):** Aceita conexões **apenas** do DockerHost (`10.10.30.10`).
    * **Porta 22 (SSH):** Aceita conexões apenas das VLANs de gestão (`10.10.10.x` e `10.10.20.x`).

### 2. Firewall de Host (UFW)
Além do OPNsense, a VM roda seu próprio firewall para impedir movimento lateral caso a rede seja comprometida.

```bash
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing)

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    10.10.20.0/24 (TRUSTED)
22/tcp                     ALLOW IN    10.10.10.0/24 (MGMT)
8200/tcp                   ALLOW IN    10.10.30.10   (DOCKERHOST)
```

### 3. Sistema Operacional
SSH: Autenticação por senha desativada. Apenas chaves Ed25519.

Updates: unattended-upgrades configurado para aplicar patches de segurança automaticamente (quando a internet é liberada temporariamente).

### 4. Armazenamento e Backup
Backend: Raft (Integrated Storage). Os dados residem em /opt/vault/data.

Criptografia: O banco de dados é criptografado em repouso.

Unseal: Requer 3 de 5 chaves para descriptografar a chave mestre na memória RAM após cada reboot.

### 5. Procedimento de Atualização (Manutenção)
Como a VM não tem internet, o processo de apt update requer passos manuais:

OPNsense: Ativar regra Temp Install Vault na VLAN SECURE.

VM Vault: Editar /etc/resolv.conf para adicionar DNS temporário (1.1.1.1).

Executar updates.

Reversão: Desativar regra no OPNsense.
