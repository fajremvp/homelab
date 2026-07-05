## Políticas de Identidade e Acesso (IAM & Zero Trust)

* **Princípios:** "Verify Explicitly" (Verifique explicitamente), "Use Least Privilege" (Menor privilégio possível) e "Assume Breach" (Assuma que já foi invadido). A identidade é o novo perímetro de segurança.

| Entidade | Método de Autenticação | Política de Acesso (RBAC) | Expiração de Sessão/Token (TTL) |
| :--- | :--- | :--- | :--- |
| **Eu (Humano/Admin)** | **MFA Obrigatório** (Passkeys/YubiKey + Senha no Vaultwarden). Acesso via SSO (Authentik). | **Admin:** Acesso amplo, mas requer elevação explícita (sudo ou re-autenticação) para operações destrutivas. | Sessão Web: 12 horas.  Token CLI: 1 hora (máx). |
| **Visitantes (Guest)** | Wi-Fi Guest (VLAN 50). Sem acesso a serviços internos. | **Nenhum:** Apenas acesso à internet com banda limitada (Throttling). Isolamento total via Firewall. | 24 horas (Rotativo). |
| **Servidores (SSH)** | Chaves SSH Ed25519. | **Sem Root:** Login apenas como usuário nominal não-privilegiado; escalação via `sudo` com log de auditoria. | N/A (Chave estática, protegida por passphrase). |
| **Vaultwarden (Service)** | Senha Mestre (Local) + 2FA App. | **Híbrido:** API Pública (Apps funcionam sem SSO). Painel Admin requer SSO Authentik. | Sessão App: Configurável. |
| **RPi (Management Edge)** | Chave SSH (Ed25519). Sem senha de root. VPN (Tailscale) | **Zero Footprint:** Sistema "Read-Only" lógico. Dados sensíveis (Cache DNS) apenas em RAM (`tmpfs`). Logs desativados. **Gatekeeper**: Atua como Jump Host para a rede de emergência. ACL de VPN: Bloqueio total por padrão; libera apenas saída para 192.168.1.200:2222. | Reboot limpa todos os dados de sessão/cache/voláteis. Expiração de Sessão/Token (TTL). VPN: Chave não expira (Machine Key). SSH: Chave estática. |
| **LXC Management (SOPS/age)** | Chave privada age local (`0600`, root only). Sem senha adicional. | **Custódia de Segredos:** Único host com poder de decriptação de `group_vars/*.sops.yaml`. Comprometimento deste host expõe todos os segredos do DockerHost e Restic. | Chave estática; rotação manual via `sops updatekeys` em caso de suspeita de vazamento. |

* **Regras de Machine-to-Machine (M2M):**
    * **Proibido Hardcoded Credentials:** Nenhum código, script ou arquivo `.env` comitado pode conter senhas ou chaves de API reais. Deve-se usar injeção de variáveis de ambiente.

### Monitoramento de Acesso (Auditoria Ativa)
* **Ferramenta:** CrowdSec (LAPI) + Collection `firix/authentik`.
* **Estado Atual:**
    - Logs de autenticação são ingeridos corretamente.
    - Eventos de falha são detectados, porém **não resultam em decisão automática**.
* **Limitação Conhecida:** Ausência de parsing válido para Authentik 2025 impede banimento automático por brute-force.
* **Proteção Efetiva:** Ataques continuam sendo mitigados no perímetro via Traefik, scanners e exploits genéricos.
