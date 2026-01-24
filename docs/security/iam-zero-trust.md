## Políticas de Identidade e Acesso (IAM & Zero Trust)

* **Princípios:** "Verify Explicitly" (Verifique explicitamente), "Use Least Privilege" (Menor privilégio possível) e "Assume Breach" (Assuma que já foi invadido). A identidade é o novo perímetro de segurança.

| Entidade | Método de Autenticação | Política de Acesso (RBAC) | Expiração de Sessão/Token (TTL) |
| :--- | :--- | :--- | :--- |
| **Eu (Humano/Admin)** | **MFA Obrigatório** (Passkeys/YubiKey + Senha no Vaultwarden). Acesso via SSO (Authentik). | **Admin:** Acesso amplo, mas requer elevação explícita (sudo ou re-autenticação) para operações destrutivas. | Sessão Web: 12 horas.  Token CLI: 1 hora (máx). |
| **Visitantes (Guest)** | Wi-Fi Guest (VLAN 50). Sem acesso a serviços internos. | **Nenhum:** Apenas acesso à internet com banda limitada (Throttling). Isolamento total via Firewall. | 24 horas (Rotativo). |
| **DockerHost (App)** | **AppRole (Vault)**. Script de boot usa SecretID protegido em disco para pegar senhas de DB em RAM. | **Leitura Estrita:** Acesso apenas a `kv/data/authentik` e `kv/data/services`. | Token renovado a cada boot/deploy. |
| **K8s (Kubernetes)** | **Service Accounts (K8s)** mapeadas para Roles do Vault via *External Secrets Operator*. | **Namespace Isolation:** O pod do "App A" só consegue decriptar segredos do namespace "App A". | Rotação automática a cada 1 hora. |
| **Servidores (SSH)** | Chaves SSH Ed25519 (Armazenadas em YubiKey ou Vault). | **Sem Root:** Login apenas como usuário nominal não-privilegiado; escalação via `sudo` com log de auditoria. | N/A (Chave estática, protegida por passphrase). |
| **Vaultwarden (Service)** | Senha Mestre (Local) + 2FA App. | **Híbrido:** API Pública (Apps funcionam sem SSO). Painel Admin requer SSO Authentik. | Sessão App: Configurável. |
| **Vault Backup (Script)** | **Token Periódico** (Auto-renovável). Script renova o token diariamente antes do snapshot. | **Policy Específica:** `sys/storage/raft/snapshot` (Permite apenas tirar foto do DB). Não lê segredos. | 30 dias / 720h (Rolling). Renovado a cada execução. |
| **RPi (AdGuard Edge)** | Chave SSH (Ed25519). Sem senha de root. | **Zero Footprint:** Sistema "Read-Only" lógico. Dados sensíveis (Cache DNS) apenas em RAM (`tmpfs`). Logs desativados. | Reboot limpa todos os dados de sessão/cache. |

* **Regras de Machine-to-Machine (M2M):**
    * **Proibido Hardcoded Credentials:** Nenhum código, script ou arquivo `.env` comitado pode conter senhas ou chaves de API reais. Deve-se usar injeção de variáveis de ambiente via Vault.
    * **Secret Leasing (Segredos Dinâmicos):** Para serviços compatíveis (ex: Banco de Dados, AWS/S3), o Vault deve gerar uma credencial temporária que expira automaticamente assim que a tarefa termina.
 
### Monitoramento de Acesso (Auditoria Ativa)
* **Ferramenta:** CrowdSec (LAPI) + Collection `firix/authentik`.
* **Estado Atual:** 
    - Logs de autenticação são ingeridos corretamente.
    - Eventos de falha são detectados, porém **não resultam em decisão automática**.
* **Limitação Conhecida:** Ausência de parsing válido para Authentik 2025 impede banimento automático por brute-force.
* **Proteção Efetiva:** Ataques continuam sendo mitigados no perímetro via Traefik, scanners e exploits genéricos.
