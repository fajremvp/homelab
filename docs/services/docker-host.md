### 5. Aplicações e Serviços (Sempre ativos)

* **VM de Aplicações (DockerHost):** `[Debian Stable]`
    * **Justificativa:** Um "servidor" centralizado para rodar todos os aplicativos em contêineres Docker. Isso mantém o Host Proxmox limpo. (Uma VM oferece melhor isolamento; um LXC é mais leve).
    * **Serviços rodando neste Host (Docker):**
    	* `Stalwart Mail Server`: A escolha definitiva. Servidor moderno escrito em **Rust** (memory-safe). Substitui Postfix/Dovecot/Rspamd por um binário único e eficiente. Suporta JMAP/IMAP/SMTP e consome apenas ~150MB de RAM. Também com aliases. Já aviso que não enviarei e-mails, somente receber (estou ciente da dificuldade de manter a famosa "reputação"). Uso de SMTP Relay externo ou e-mail comum que já uso (Tuta e Proton) caso haja bloqueio da porta 25 pelo ISP.
    	* `Nostr Relay (Strfry)`: Servidor de retransmissão de alta performance escrito em C++. Configurado com *whitelist* de escrita (apenas sua chave privada pode postar/fazer backup) e leitura pública. Garante soberania dos dados e resistência à censura. Será exposto também via Tor (Onion Service).
        * `Vaultwarden` (Gerenciador de senhas)
        * `Syncthing` (Sincronização)
        * `Forgejo`(Pull Mirror): Servidor Git auto-hospedado. Será configurado como um "pull mirror" (somente leitura) que puxa automaticamente as mudanças do GitHub (usado como repositório primário/público).
        * `Forgejo Actions`(CI/CD): Utilizado para rodar pipelines de teste locais (no homelab) sobre o código espelhado, permitindo validar integrações com outros serviços internos.
        * `FreshRSS` (Fonte de informações descentralizadas e distribuídas)
        * `Grafana + Prometheus + Loki` (Observabilidade: Métricas e Logs)
        	- **Política:** Retenção de logs configurada para **7 dias** para evitar que o armazenamento de logs lote o SSD NVMe principal.
        * `ntfy` (Servidor de Notificações): Alternativa soberana ao Discord/Slack. Recebe webhooks do Alertmanager/Grafana e envia push notifications para o celular.
        * `Portfólio pessoal` (Servidor web, via Traefik (também disponível em .onion e IPFS))
        * `Pequeno site` (Servidor web, via Traefik)

* **Bitcoin Core (Full Node) (Sem depender de intermediários e terceiros):** `[VM Dedicada]`
    * **Justificativa:** Alto uso de I/O de disco e rede constante. Uma VM dedicada impede que ele cause latência ou sature os recursos de outros serviços críticos.
    * **Armazenamento:** Montado no **SSD SATA Dedicado**. Isso protege o NVMe principal de desgaste e latência.

* **Terraform / Ansible / Restic:** `[LXC Alpine - Gerenciamento]`
    * **Justificativa:** Centraliza as ferramentas de automação, IaC e backup. O **Terraform** será usado para *provisionar* a infraestrutura (VMs, LXCs) de forma declarativa. O **Ansible** será usado para *configurar* o software *dentro* dessas VMs (instalar pacotes, aplicar hardening). O **Restic** gerencia os scripts de backup de dados. Rodarão a partir de um LXC "admin" dedicado.

* **Resiliência de Boot**: Todos os containers críticos (Vaultwarden, Stalwart) devem ser configurados com restart: always ou restart: on-failure:10. Isso garante que, se tentarem subir antes do Vault estar pronto, eles continuarão tentando até conseguirem a senha.

### Serviços Sob Demanda (Não vão estar sempre ligados)

* **Aplicações Sob Demanda (Docker):** `[DockerHost]`
    * **Justificativa:** Podem rodar no mesmo DockerHost dos serviços "Sempre Ativos", basta ligar e desligar os contêineres conforme necessário (`docker-compose up -d` e `docker-compose down`).
        * `Mattermost`(Alternativa ao Slack)
        * `OnlyOffice`(Alternativa ao Docs)
        * `HedgeDoc`(Anotações e brainstorming em grupo)
        * `Jitsi Meet`(Alternativa ao Meet (para no máximo umas 8 pessoas, somente chamada de áudio, sem video, talvez no máximo so alguém compartilhando a tela))
        * `Servidor de Minecraft`(Survival Vanilla para jogar com até 3 amigos)
