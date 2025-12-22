### 7.3. Gestão de Chaves Mestra (Vault Unseal)

* **Estratégia**: Disponibilidade automática (Auto-Unseal).
* **Mecanismo**: O Vault inicia selado, mas um script de systemd (protegido como root) injeta a chave de desbloqueio automaticamente no boot.
* **Justificativa**: Garante que serviços dependentes (como e-mail e DNS) subam sozinhos após queda de energia.
* **Cold Storage (Obrigatório)**: Devem ser armazenados offline (Papel/Pendrive VeraCrypt) para recuperação de desastre total:
	* A **Master Unseal Key** do Vault.
	* A **Senha de Criptografia do Repositório Restic** (Sem isso, o backup no Backblaze é irrecuperável).
	* A **Chave de Recuperação (Recovery Key)** do Identidade Soberana (Nostr/Bitcoin).
	* O **Par de Chaves SSH** (`~/.ssh/id_ed25519`) do computador Admin (sua única chave para entrar no servidor).