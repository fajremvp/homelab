## Gestão de Chaves Mestra (Vault Unseal)

* **Estratégia**: Shamir's Secret Sharing (Manual Unseal).
* **Mecanismo**: O Vault inicia **Selado**. A memória RAM é apagada no desligamento, levando as chaves de criptografia.
* **Justificativa**: Garante que, se o servidor for roubado fisicamente (disco removido ou boot forçado), os dados do cofre (e consequentemente as senhas do Authentik/Banco) permaneçam matematicamente inacessíveis.
* **Automação de Consumo**: Embora o *desbloqueio* do cofre seja manual, a *leitura* das senhas pelos serviços (DockerHost) é automatizada via script de retry (Systemd), eliminando a necessidade de intervenção humana na camada de aplicação.
* **Cold Storage (Obrigatório)**: Devem ser armazenados offline (Papel/Pendrive VeraCrypt):
	* As **3 Chaves de Unseal** do Vault.
	* O **Root Token** (apenas para emergências, revogar se possível).
    * (Demais chaves mantidas...)
