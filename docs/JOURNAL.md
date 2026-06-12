# Diário de Bordo

Este arquivo documenta a jornada, erros, aprendizados e decisões diárias.
Para mudanças estruturais formais, veja o [CHANGELOG](../CHANGELOG.md).

---
## 2026-06-12
**Status:** ✅ Sucesso

**Foco:** Migração de Paradigma (Do Tududi para o Obsidian) e Risco no Storage Efêmero

- **A Filosofia do Segundo Cérebro:** Percebi que o Tududi nunca funcionaria como a "wiki pessoal" que eu buscava. Eu precisava de uma base de conhecimento que crescesse comigo ao longo do tempo, não presa a bancos de dados proprietários, mas sim em arquivos abertos e locais (Markdown). O objetivo é centralizar e correlacionar diferentes áreas em um sistema interconectado que futuramente possa alimentar uma IA. O **Obsidian** atende a tudo isso magistralmente.
- **Topologia de Sincronização:** Aproveitei a VM `DockerHost` que já rodava o Syncthing e implementei uma topologia Hub-and-Spoke. O servidor atua como nó central "Always-On", enquanto meu NixOS e o Galaxy M55 atuam como satélites. Configurei o *Staggered File Versioning* no lado do servidor para garantir histórico de alterações e rollbacks.
- **O Quase Desastre (Storage Efêmero):** Ao configurar a pasta na GUI do Syncthing, apontei o *Folder Path* para `/var/syncthing/Mirror` esquecendo o subdiretório `/data/` que estava mapeado no `docker-compose.yml`. Resultado: O cofre estava sendo gravado na camada efêmera do Docker e seria aniquilado no próximo `docker compose down`.
    - *Resolução:* Extraí os dados via `docker cp`, corrigi o `chown` para PUID 1000, parei o container e alterei o `config.xml` na mão para `/var/syncthing/data/Mirror`.
- **Fechando a Falha de Backup:** O disco secundário (`/mnt/syncthing/`) estava fora da política de backup do Restic por design. Ajustei o playbook do Ansible e o script do servidor para fazer a ingestão cirúrgica de `/mnt/syncthing/Mirror`. Backup testado e validado com sucesso pro Backblaze B2.
- **Limpeza:** O stack inteiro do Tududi (pastas, rede, Compose e variáveis Ansible) foi dizimado do código e do host. Infraestrutura limpa.

## 2026-06-07
**Status:** ✅ Sucesso

**Foco:** Homologação do Security Funnel (CrowdSec + Traefik + OPNsense)

- **Desafio 1 (Músculo Desconectado):** O Bouncer do OPNsense não estava recebendo os IPs banidos pois a interface web (plugin `os-crowdsec`) falha ao validar configurações sem a LAPI local ligada.
- **Solução 1:** Utilizado o *workaround* de gerar um botão de Apply falso na UI e inserida a chave manualmente em `/usr/local/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml`. As tabelas nativas `crowdsec_blocklists` do kernel foram alimentadas com >5500 IPs maliciosos.
- **Desafio 2 (Cérebro Cego - HTTP):** O CrowdSec analisava erros SSH, mas estava cego para ataques web. Motivo: O Traefik emite apenas logs do aplicativo (DEBUG) por padrão, e não logs de quem acessa o quê.
- **Solução 2:** Injetadas as flags `--accesslog=true` e `--accesslog.format=json` na configuração do Traefik.
- **Desafio 3 (Docker Socket Proxy 403):** Ao refatorar a aquisição de logs do CrowdSec para buscar dados nativos do Docker (evitando IDs hardcoded no `.yaml`), o Socket Proxy rejeitou o comando `GET /info` com `403 Forbidden`.
- **Solução 3:** Habilitada a variável `INFO=1` no Socket Proxy, restabelecendo a confiança entre os containers e permitindo a descoberta dinâmica.
- **Resultado Final:** Ataques HTTP agora são "parseados" em tempo real. Se um script tentar invadir o portal, o Traefik avisa o CrowdSec, que emite um push via Ntfy e o OPNsense derruba o IP na mesma hora.

## 2026-06-06 (Parte 2)
**Status:** ✅ Sucesso

**Foco:** Expansão da Camada Zero Trust (ForwardAuth no Actual Budget)

- **Desafio:** O `Actual Budget` estava operando com a interface de web totalmente exposta na rede local sem o filtro de MFA da borda, para facilitar o uso no celular. Isso feria parcialmente a política de "Defense in Depth" (onde nenhuma interface administrativa ou de app deve estar acessível sem token válido).
- **Solução:** Como o serviço opera de forma consistente via navegador (PWA) e lida corretamente com redirecionamentos HTTP, a blindagem do Authentik pôde ser ativada sem quebrar a experiência mobile.
- **Implementação:** Injetada a label `traefik.http.routers.actualbudget.middlewares=authentik@docker` no arquivo `docker-compose.yml` e criada a App/Provider/Outpost correspondente na UI do Authentik. O tráfego não autenticado agora é bloqueado com sucesso na camada L7 pelo Traefik antes de chegar no container do software financeiro.

## 2026-06-06
**Status:** ✅ Sucesso

**Foco:** Refatoração da Estratégia de Disaster Recovery (Local Air-Gapped)

- **Desafio:** A estratégia de DR dependia significativamente de recuperação através da internet (Restic via B2). Isso resolvia a disponibilidade dos dados, mas o RTO (Tempo de Recuperação) em um Bare Metal Restore seria alto devido ao download, e faltava uma camada de resiliência física local contra interrupções de ISP. Outro fator considerado foi a proteção contra eventos físicos e operacionais, como falha catastrófica de hardware, corrupção de dados, exclusão acidental, ransomware, roubo de equipamentos, acesso físico não autorizado, raios e até incêndios. Embora o Backblaze B2 forneça uma cópia geograficamente separada, a ausência de uma mídia local dedicada dificultava recuperações rápidas e aumentava a dependência de um único caminho de restauração.
- **Solução:** Implementei um HD de 1TB (WD Blue) no meu notebook NixOS para atuar como checkpoint discreto. Não é um storage contínuo ou síncrono, mas sim uma mídia dedicada para execução de scripts de *pull* isolados.
- **Desenvolvimento do Script (`dr-checkpoint.sh`):** - O script conecta no Proxmox e nos nós, gera dumps locais (Vault/PG) e dispara o `vzdump` englobando as VMs e LXCs.
    - Ele captura o `/etc/pve/storage.cfg`, `interfaces` e `/etc/fstab` do Proxmox. Sem isso, o restore de VMs em um hardware novo vira um pesadelo de alocação de discos.
    - Puxa os dados do Syncthing, mantendo a pasta `.stversions` preservada para proteção local contra ransomware.
- **Troubleshooting e Lições Aprendidas:**
    - *Sudo sem TTY:* Tentar rodar comandos via SSH com pipe (`|`) e `sudo` falhava silenciosamente porque o sudo não tinha um terminal para pedir senha. Resolvi executando em subshell (`sudo bash -c`).
    - *Eval e Rsync:* O uso do comando `eval` engolia as aspas do `--rsync-path="sudo rsync"`, quebrando a sintaxe no receptor. Removi o `eval` e confiei no parser nativo do bash.
    - *Lixo de LXC:* O VZDump gera `.tar.zst` para containers e `.vma.zst` para VMs. O script original só limpava as extensões de VM do Host, causando acúmulo de ISOs pesadas a cada cancelamento.
- **Resultado:** O checkpoint levou 29 minutos e pesou 46GB. Com a criptografia LUKS em todas as camadas (Hypervisor, Nuvem e HD Local NixOS), a soberania está garantida contra quebra física, ataques cibernéticos e roubo de hardware.

## 2026-05-26
**Status:** ✅ Sucesso

**Foco:** Hospedagem do Portfólio (Shellfolio/Astro) na rede Tor e implementação de CI/CD.

- **Desafio:** Como espelhar a experiência mágica e ágil de deploy do Cloudflare Pages no meu próprio Homelab, rodando o site na rede Tor, sem abrir mão da segurança Zero Trust?
- **Evolução Arquitetural:**
    - *Ideia Inicial:* Construir a imagem via GitHub Actions, jogar no GHCR (GitHub Registry) e usar o Watchtower no DockerHost para baixar a imagem nova e reiniciar.
    - *O Refinamento:* Apesar de prático, depender do ecossistema da Microsoft/GitHub para compilar o site feria o princípio fundamental da Soberania Total. A infraestrutura deveria funcionar perfeitamente mesmo se a internet comercial caísse.
    - *Decisão Final:* Utilizar a funcionalidade nativa e clássica do Git: **Bare Repository + Git Hooks**. O próprio DockerHost recebe o push via SSH, executa a compilação localmente num container efêmero e joga os arquivos (`dist/`) pro Nginx servir.
- **Troubleshooting e Lições Aprendidas:**
    - **Root no Docker:** Se o container temporário do Node.js rodasse a compilação por padrão, a pasta gerada pertenceria ao usuário `root`. No push seguinte, o Git (rodando como `fajre`) retornaria falha de "Permission Denied". A solução foi injetar o UID/GID do host no comando de execução (`--user $(id -u):$(id -g)`).
    - **Linter vs Realidade:** Ao codificar a automação no Ansible (`services.yml`), o `ansible-lint` barrou o commit local, apontando o erro `command-instead-of-module` por eu ter rodado `git init --bare` via shell no lugar do módulo git nativo do Ansible. Como o módulo nativo foca em clonar e não em criar repositórios crus, adicionei a tag de exceção `# noqa command-instead-of-module`, mantendo a cultura de *Shift-Left Security* rigorosa, mas inteligente.
    - **Hardening de Borda:** A versão do compilador foi estritamente cravada (`node:22.12.0-alpine`) para garantir builds determinísticos, e os contêineres do Nginx e Tor sofreram restrição severa de Cgroups.
- **Resultado:** Um simples `git push homelab main` disparado do meu NixOS constrói e atualiza meu domínio `.onion` localmente em 5 segundos. Nenhuma porta exposta para a WAN. Automação impecável.

## 2026-05-16
**Status:** ✅ Sucesso (Ergonomia Física e Documentação)

**Foco:** Redução de poluição visual e atualização arquitetural do Client (NixOS).

- **Ergonomia e Ambiente:** As luzes (LEDs) das ventoinhas do gabinete do servidor e do Nobreak foram completamente desligadas. O objetivo é reduzir a poluição luminosa no ambiente, tornando a presença do homelab mais discreta.
- **Manutenção de Documentação:** Toda a documentação do repositório foi revisada e ajustada. Como migrei meu notebook pessoal do Arch Linux para o **NixOS**, as referências arquiteturais aos clientes da infraestrutura precisavam refletir essa nova realidade de forma precisa.

## 2026-05-10
**Status:** ✅ Sucesso (Integração de Novo Client OS)

**Foco:** Restabelecimento de comunicação P2P (Syncthing) após migração para NixOS.

- **Migração para NixOS:** Com a substituição do Arch Linux pelo NixOS no meu notebook, o node precisou ser reajustado.
- **Reajuste do Syncthing:** Realizei a reconfiguração do Syncthing no novo sistema operacional, sincronizando novamente com o DockerHost para garantir o fluxo de arquivos.

## 2026-05-07
**Status:** ✅ Sucesso (Controle de Ciclo de Vida)

**Foco:** Alteração da política de reinício do servidor de Minecraft.

- **Controle Manual Absoluto:** Removi a política `restart: unless-stopped` do `docker-compose.yml` e defini explicitamente `restart: "no"`.
- **Motivação e Resultado:** O container do PaperMC subia automaticamente após reboots do host, restarts do Docker daemon ou em execuções automáticas do Ansible/Compose. Agora, o servidor só sobe quando eu executo manualmente `docker compose up -d`. Isso me dá controle total sobre quando ele fica online, evitando reinicializações inesperadas e updates automáticos da imagem em momentos indesejados.

## 2026-05-05
**Status:** ✅ Sucesso (Auditoria de Produção e Tuning de Observabilidade)

**Foco:** Comprovação da estabilidade do nó financeiro (Fase 4) e ajuste fino do Dead Man's Switch.

- **Auditoria OrangeShadow (Fase 4 em Produção):** Entre os dias 04/05 e 05/05, executei uma auditoria profunda na VM OrangeShadow para validar a sua operação contínua 24/7.
    - **Logs & Sincronia:** Ao rodar `tail` nos logs, vi o Monero cravar a mensagem "You are now synchronized with the network". O Bitcoin atualizou o *tip* da blockchain conectando-se a peers da Darknet (`block-relay-only v2`).
    - **Consumo Físico:** O comando `free -h` comprovou que a memória está sob controle: 3.3Gi de RAM em uso real e o Swap absorvendo 1.8Gi.
    - **Colete de Força (Cgroups):** O `systemctl status bitcoind electrs monerod tor@default` confirmou todos como `active (running)`. O Kernel respeitou magistralmente os limites do Systemd: Bitcoin cravado em 2.9G de 3G, Monero em 2.9G de 3G e Electrs em 771.9M de 1G. A máquina opera firme, blindada, sem vazar dados e sem sufocar os recursos do host.
- **Tuning do Healthchecks.io (Redução de Ruído):**
    - Ajustei o monitoramento do DockerHost para reduzir falsos positivos de indisponibilidade.
    - **Ação:** O heartbeat continua enviando pings a cada 5 minutos, mas aumentei o `Grace Time` de 2 para **10 minutos**.
    - **Resultado:** O sistema agora só considera o host como DOWN após ~15 minutos sem resposta. Essa janela torna o monitoramento tolerante a oscilações momentâneas de rede, atrasos do Docker, falhas transitórias de DNS ou pequenas interrupções da internet.

## 2026-05-03
**Status:** ✅ Sucesso

**Foco:** Implementação de Redundância e Espelhamento Git (Multi-Remote).

- **Descentralização do Repositório:** Consolidei a redundância da infraestrutura configurando um fluxo de *Multi-Remote* no Git.
- **Mecanismo:** Todo o código (junto das assinaturas GPG) agora é enviado simultaneamente para o GitHub e para o **Codeberg** (`https://codeberg.org/fajre/homelab`) a cada execução de `git push`.
- **Resultado:** Um backup espelhado, descentralizado e à prova de falhas/censura de uma única plataforma.

## 2026-05-02
**Status:** ✅ Sucesso (Validação Operacional do DNS Secundário - RPi)

**Foco:** Auditoria completa do AdGuard Home secundário (`192.168.1.5`) para validar funcionamento, privacidade (Zero Footprint) e failover automático.

- **Motivação:** Nunca havia sido realizado um teste formal e documentado de todos os aspectos do DNS secundário desde sua implementação em 2026-01-19. Com o ambiente estável, executou-se uma bateria completa de testes operacionais.

- **Testes Realizados e Resultados:**
    1. **Serviço ativo:** `systemctl status AdGuardHome` confirmou `active (running)` desde 30/03/2026 — uptime de 1 mês e 2 dias sem interrupção. Journald com apenas 1 linha (start do systemd), zero queries logadas no sistema.
    2. **tmpfs montado e protegido:** tmpfs on /opt/AdGuardHome/data type tmpfs (rw,relatime,size=131072k,mode=700). Tamanho: 128M. Permissões `0700` (somente root). O usuário `fajre` não consegue acessar o diretório sem privilégios elevados (`ls: cannot access '/opt/AdGuardHome/data/': Permission denied`).
    3. **Logs desativados na configuração:**
        - Confirmado via `grep` no `AdGuardHome.yaml` com privilégios elevados.
        ```yaml
        querylog:
        enabled: false
        size_memory: 0
        statistics:
        enabled: false
        ```
    4. **DNS respondendo e filtrando:**
        - `dig @192.168.1.5 google.com` → `NOERROR`, resposta em **0ms** (cache hit). ✅
        - `dig @192.168.1.5 doubleclick.net` → `127.0.0.1` (bloqueado pela lista OISD). ✅
    5. **Failover com LXC primário derrubado:**
        - LXC AdGuard-Primary (101) parado via GUI do Proxmox.
        - `dig @192.168.1.5 github.com` → `NOERROR` em 3ms. ✅
        - `resolvectl flush-caches` executado para garantir ausência de cache.
        - `resolvectl query github.com` → `4.228.31.150` via `enp1s0f1` em **1.5ms**. ✅
        - Failover confirmado no nível do sistema operacional, não apenas via `dig` direto.
    6. **Zero Footprint - Restart de serviço (amnésia parcial):**
        - `systemctl restart AdGuardHome` não apaga o tmpfs — apenas reinicia o processo.
        - `stats.db` sobreviveu ao restart com timestamp atualizado (comportamento correto e esperado).
        - **Conclusão:** A amnésia total só ocorre no reboot físico do hardware, não no restart do serviço. Comportamento arquitetural documentado conscientemente.
    7. **Zero Footprint - Reboot físico (amnésia total):**
        - Antes do reboot: `stats.db` = 65536 bytes, `sessions.db` = 16384 bytes.
        - `sudo reboot` executado no RPi.
        - Após o boot: `stats.db` = 16384 bytes (zerado), `sessions.db` = 16384 bytes (zerado), timestamps recriados em `May 2 19:39`. ✅
        - **Nenhum histórico de queries sobreviveu ao reboot físico. Zero Footprint confirmado empiricamente.**

- **Observação - `nslookup` durante o failover:**
    - Com o LXC primário desligado, `nslookup github.com` retornou `Server: 10.10.30.5` - indicando que o `systemd-resolved` ainda tinha o primário em cache. Isso evidencia que o teste de failover real exige `resolvectl flush-caches` antes, caso contrário o resultado é falso positivo. Procedimento adicionado ao runbook de DR.

- **Resultado Final:**

    | Teste | Resultado |
    |:------|:----------|
    | Serviço ativo (uptime 33 dias) | ✅ |
    | tmpfs montado (`mode=700`) | ✅ |
    | querylog desativado no YAML | ✅ |
    | Journald silenciado (1 linha) | ✅ |
    | DNS respondendo (`google.com`) | ✅ |
    | Bloqueio OISD (`doubleclick.net` → `127.0.0.1`) | ✅ |
    | Failover com flush de cache | ✅ |
    | Amnésia no restart de serviço (tmpfs persiste) | ✅ esperado |
    | Amnésia no reboot físico (tmpfs destruído) | ✅ |

- **Documentação:** Adicionado Runbook de teste de failover e verificação de amnésia no `disaster-recovery.md`.

## 2026-05-01
**Status:** ✅ Sucesso (Implementação do Speedtest Tracker, SRE e Observabilidade)

**Foco:** Monitoramento histórico da performance da ISP (Download/Upload/Ping), diagnóstico de gargalos via cAdvisor e integração com Prometheus/Grafana.

- **Implementação Inicial e GitOps:**
  - **Serviço:** Adicionado o `speedtest-tracker` (imagem `lscr.io/linuxserver/speedtest-tracker:latest`) via Docker Compose na VM DockerHost.
  - **Segurança:** O painel na rota `speedtest-tracker.home` foi blindado pelo Traefik + Authentik (ForwardAuth). O `.env` com a `APP_KEY` do Laravel foi fornecido via Ansible (`vars_prompt`), mantendo o git protegido.
  - **Armazenamento:** Optado por SQLite nativo no diretório `/opt/services/speedtest-tracker/data`, garantindo que o backup diário automático do Restic faça a captura consistente sem necessidade de dumps complexos.
  - **Incidente de Path no Ansible:** O deploy inicial falhou (Erro `rsync code 23`). A causa foi uma divergência entre a pasta criada (`speedtest-tracker`) e o caminho no módulo `synchronize` do `services.yml` (`speedtest`). Corrigido rapidamente no playbook.

- **Prometheus (Crash Loop e TLS):**
  - A exposição e raspagem das métricas no endpoint `/prometheus` do Speedtest Tracker apresentou desafios técnicos e causou downtime temporário no serviço de monitoramento:
    - **Tentativa 1 (HTTP/80):** Falhou. Como a variável `APP_URL` estava definida como `https`, o Nginx interno do container forçou um redirecionamento (HTTP 301) que o Prometheus não soube lidar.
    - **Tentativa 2 (Erro de Sintaxe e Crash Loop):** Uma tentativa de injetar headers (`X-Forwarded-Proto`) gerou um erro de sintaxe no `prometheus.yml` (parâmetro `http_config` > `headers` inexistente no escopo do `scrape_configs`). O Prometheus entrou em *Crash Loop* (Erro: `field http_config not found in type config.ScrapeConfig`).
    - **Solução:** O `prometheus.yml` foi corrigido para raspar a porta **443** (HTTPS interno do container). Como o certificado gerado pelo LinuxServer.io é autoassinado (não possui SAN), foi obrigatório adicionar a flag oficial `insecure_skip_verify: true` sob `tls_config`. O Prometheus voltou à vida imediatamente e os dados fluíram.

- **Profiling de Rede: Bare Metal vs Docker (cAdvisor)**
  - Identificado uma aparente discrepância inicial na velocidade: O Arch Linux (Bare Metal na VLAN 20) bateu **408.3 Mbps** de download, enquanto o container do Speedtest registrava médias de **~351 Mbps**.
    - **Investigação SRE e Falso Positivo:** A primeira suspeita foi gargalo de CPU (`0.75` cores), mas o cAdvisor provou uso de apenas 1.25%. A segunda suspeita foi overhead de NAT do Docker.
    - **Realidade (Plano da ISP):** Após acompanhamento de 24 horas, os logs mostraram resultados perfeitamente consistentes de `351.5 Mbps / 173 Mbps`. Isso corresponde **exatamente** ao plano contratado da ISP (Unifique 350/175). O pico de 408 Mbps no Bare Metal era apenas *Overprovisioning/Burst* inicial da operadora, e não a linha de base real.
    - **Conclusão e Ajustes:** O container não possui gargalo e entrega 100% da banda contratada. Mantive a CPU em `0.75` e os limites de alerta (Thresholds) em **300 Mbps (DL)** e **150 Mbps (UL)**. Essa "gordura" de 15% evita fadiga de alertas por oscilações naturais da rota.

- **Notificações e Dashboards:**
  - **Notificações:** Desativei todas as integrações de Webhook (incluindo Ntfy), pois a documentação oficial alertava que elas estão *deprecated* em prol do Apprise. Evitamos dívida técnica futura.
  - **AdGuard Home:** Adicionada a regra customizada `@@||icanhazip.com^` para evitar que bloqueadores de DNS interrompessem o estágio de checagem (Checking) do Speedtest.
  - **Grafana:** Importado o Dashboard comunitário (ID `24608`, Prometheus Edition) e persistido como JSON no repositório. O "Single Pane of Glass" agora consolida métricas de banda, jitter e perda de pacotes da infraestrutura.

## 2026-04-24
**Status:** ✅ Sucesso (Manutenção Evolutiva e Hardening de CI/CD)

**Foco:** Atualização de serviços, aprimoramento da observabilidade de energia e sincronização estrita de documentação do pipeline.

- **Atualização de Serviço (Actual Budget):**
  - O container do gerenciador financeiro foi atualizado com sucesso para a release mais recente (`26.4.0`).

- **Observabilidade de Energia (Grafana):**
  - Identificada a necessidade de visualizar o comportamento da bateria ao longo do tempo. Adicionado o gráfico **Battery Charge History** no painel do UPS/Nobreak. Isso permite correlacionar o histórico de retenção de carga com os eventos de queda de energia, ajudando a prever a degradação física das baterias.

- **Segurança de CI/CD (Hardening do Gitleaks):**
  - O hook do Gitleaks no `.pre-commit-config.yaml` foi enrijecido. Foram adicionados os argumentos `"--exit-code", "1"`.
  - **Ação:** Agora, a detecção de qualquer segredo resulta em falha obrigatória (Hard Block) do commit, impedindo que o vazamento ocorra mesmo se o desenvolvedor ignorar o aviso visual.

- **Sincronização e Saneamento de Documentação Técnica:**
  - O documento `development-standards.md` estava defasado em relação à realidade do pipeline de pre-commit. Foi executada uma refatoração completa para alinhar a teoria à prática:
    - **Novos Hooks Documentados:** Adicionadas as descrições para os hooks de higiene e integridade (`check-added-large-files`, `check-merge-conflict`, e `detect-private-key`).
    - **Correção de Severidade:** O status do `shellcheck` foi corrigido de "Warning" para "Crítico (Block)".
    - **Refinamento de Detalhes:** Especificados os argumentos reais em uso: inclusão da flag `--redact` no Gitleaks, perfil *relaxed* (e exclusão de templates `.j2`) no Yamllint, perfil *basic* no Ansible Lint e o uso do wrapper Python para o ShellCheck.

## 2026-04-19
**Status:** ✅ Sucesso (Trabalho Acadêmico — Testes de Aceitação Operacional)

**Foco:** Apresentação prática de OAT (Operational Acceptance Testing) para a disciplina de Testes de Software, utilizando o Homelab como ambiente real de produção.

**Contexto:**
    - Trabalho em grupo sobre Testes de Aceitação. Minha responsabilidade foi a parte de **OAT (Testes Operacionais)**, demonstrando que um sistema não basta funcionar, ele precisa ser seguro, resiliente e isolado sob carga real.
    - Minha parte da apresentação foi dividida em duas partes, ambas usando a infraestrutura do Homelab ao vivo.

**Shift-Left Security (Pre-Commit como Teste de Aceitação Antecipado):**
    - O primeira parte demonstrou o conceito de **Shift-Left**, onde a validação de qualidade e segurança ocorre na estação do desenvolvedor, antes do `git commit`, e não somente em produção ou na esteira de CI/CD.
        - **Ferramenta:** Framework `pre-commit` (já presente na infra em `.pre-commit-config.yaml`).
        - **Demonstração prática:**
            1. **Vazamento de credencial:** Um arquivo com uma chave de acesso simulada foi adicionado ao stage. O hook **Gitleaks** detectou o vazamento em milissegundos e **bloqueou o commit**. O histórico do Git permaneceu limpo.
            2. **Formatação suja:** Arquivo com espaços em branco e sem quebra de linha no final. Os hooks `trailing-whitespace` e `end-of-file-fixer` **corrigiram automaticamente** o arquivo antes do commit.
            3. **Commit limpo:** Após remover a credencial e o arquivo ter sido autocorrigido, o commit foi aceito com todos os hooks passando.
        - **Lição demonstrada:** Erros básicos de segurança e formatação detectados na origem jamais chegam ao histórico do repositório, liberando esteiras posteriores para focarem em testes mais avançados.

**OAT na Prática: Segurança e Isolamento de Recursos:**
    - A segunda parte demonstrou dois critérios clássicos de aceitação operacional, ambos também validados ao vivo contra o Homelab.
    **Segurança (Zero Trust + SSO):**
        - **Critério de aceitação:** *Nenhum recurso interno pode ser acessado sem autenticação validada.*
        - **Ferramenta:** `curl --head --insecure https://grafana.home`
        - **Resultado observado:**
            - Acesso sem autenticação retornou **HTTP 302**, redirecionando para o Authentik (IdP). O Grafana nunca foi entregue diretamente.
            - Tentativa de acesso direto à porta interna do serviço **falhou** (connection refused), confirmando que nenhuma porta de serviço está exposta diretamente na rede.
            - Acesso via navegador confirmou o fluxo completo: redirect → Authentik → login com MFA → autorização por grupo (`infra-admins`).
        - **Observação de OPSEC levantada durante a apresentação:** Mesmo sem acesso ao conteúdo, os headers HTTP da resposta revelam que o sistema utiliza o Authentik. Um atacante em fase de reconhecimento conseguiria mapear o IdP da infraestrutura.
        - **Conclusão:** Critério de segurança **APROVADO**.
    **Performance e Isolamento de Recursos (Blast Radius):**
        - **Critério de aceitação:** *Um serviço sobrecarregado não pode consumir todos os recursos da máquina e derrubar serviços vizinhos críticos.*
        - **Ferramenta:** Apache JMeter, com 250 usuários simultâneos, requisições ininterruptas por 1 minuto, alvo: container `whoami` (serviço de teste leve, escrito em Go).
        - **Configuração do alvo:** Limites intencionalmente rígidos no Docker Compose (`cpus: 0.1`, `memory: 50M`) para forçar saturação controlada.
        - **Monitoramento:** Grafana ao vivo com dashboards do cAdvisor (métricas por container).
        - **Resultado observado:**
            - CPU e rede do container `whoami` dispararam e atingiram o teto definido pelos Cgroups do Linux.
        - **Mecanismo explicado:** O Docker utiliza **Cgroups** do Linux para impor limites físicos no kernel. O impacto ficou contido estritamente no container alvo, ou seja, o **blast radius foi controlado**.
        - **Conclusão:** Critério de isolamento de recursos **APROVADO**.

## 2026-03-29
**Status:** ✅ Sucesso (Expansão de Recursos da VM DockerHost)

**Foco:** Aumento de RAM e disco da VM DockerHost para acomodar a carga crescente de containers.

- **Motivação:**
    - A entrada de 2026-03-28 já havia sinalizado o risco: durante o boot do Minecraft, a RAM da VM saltou para 5.5GB e acionou 87% do swap de 2GB. Com 8GB estáticos e múltiplos serviços pesados (Authentik/PostgreSQL, Prometheus, Loki, Syncthing, PaperMC), a margem de segurança havia se esgotado.
    - O disco raiz de 32GB (ext4) estava em **81% de ocupação** (23GB usados de 29GB disponíveis), criando risco real de exaustão que travaria os containers via `no space left on device`.

- **Implementação - RAM (8GB -> 12GB):**
    - Alterado via GUI no Proxmox.
    - A VM reiniciou com 12GB alocados (`11Gi` visíveis pelo kernel - normal, overhead do sistema).
    - Ballooning permanece desativado (`balloon: 0`), conforme padrão da infraestrutura para VMs de produção com serviços Java/stateful.

- **Implementação - Disco (32GB -> 64GB):**
    - Expansão do disco virtual no hypervisor: `qm resize 105 scsi0 +32G`.
    - **Obstáculo (Swap como Bloqueio L2):** O `growpart` falhou com `NOCHANGE: partition 2 is size 61630464. it cannot be grown`. Causa: a partição `sda3` (swap de 1.7GB criada durante a instalação) ocupava o espaço imediatamente após a `sda2`, impedindo sua extensão.
    - **Resolução (fdisk + swapfile):**
        1. Partição `sda3` removida via `fdisk` (sem necessidade de `swapoff` prévio, pois o swap não estava ativo no momento).
        2. `growpart /dev/sda 2` expandiu com sucesso a partição raiz para ~63GB.
        3. `resize2fs /dev/sda2` expandiu o filesystem ext4 online, sem necessidade de desmontar.
        4. Swap recriado como **arquivo** (`/swapfile` de 2GB via `fallocate`), em vez de partição - solução mais flexível e elegante, pois permite redimensionamento futuro sem reparticionar.
        5. UUID da partição antiga removido do `/etc/fstab`; entrada do `/swapfile` adicionada.
    - **Resultado:** Disco raiz passou de **29G (81% cheio)** para **62G (41% cheio)**, com 36GB livres.

- **Hardening Pós-Expansão:**
    - Aplicado `vm.swappiness=1` via `/etc/sysctl.d/99-swappiness.conf`, alinhando o comportamento ao padrão das outras VMs de produção (OrangeShadow usa `vm.swappiness=10`). O kernel só recorrerá ao swap em situação de esgotamento absoluto de RAM física.

## 2026-03-28
**Status:** ✅ Sucesso (Implementação de Servidor Minecraft)

**Foco:** Deploy do PaperMC, tuning do Java, eficiência energética e liberação restrita via Tailscale.

- **Implementação:**
    - Utilizada a imagem `itzg/minecraft-server` em `/opt/services/minecraft` (já contemplado automaticamente no backup diário do Restic).
    - Motor alterado para **PaperMC** (`TYPE=PAPER`) para máxima otimização sem alterar o client-side (Vanilla).
    - Mundo gerado com sucesso utilizando a seed customizada (`SEED="-3361685360695458093"` - aspas duplas exigidas no YAML para números negativos).
    - **Otimização Java e Auto-Pause:** Configurado `PAUSE_WHEN_EMPTY_SECONDS=60` para hibernar o servidor quando vazio. Para evitar conflitos e crashes (falsos positivos do watchdog), as variáveis `MAX_TICK_TIME=-1` e `JVM_DD_OPTS=disable.watchdog:true` foram aplicadas, em conjunto com as famosas flags de otimização do Aikar (`USE_AIKAR_FLAGS=true`).

- **Segurança & Rede (Zero Trust):**
    - Sem NAT no OPNsense. Acesso ocorre puramente via Tailscale.
    - Criado `group:minecraft` no `acls.hujson` permitindo acesso estrito ao destino `10.10.30.10:25565`.

- **Troubleshooting & Aprendizados:**
    - **Erro de Limite de CPU (Cgroups):** Ao tentar definir `cpus: '2.0'` no `deploy.resources`, o Docker retornou erro (`range of CPUs is from 0.01 to 2.00, as there are only 2 CPUs available`).
        - *Solução:* Ajustado para `1.5`. A VM do DockerHost possui apenas 2 vCores no Proxmox. O limite de 1.5 concede potência suficiente à engine do jogo (que é essencialmente single-thread) e reserva os 0.5 vCores restantes para a sobrevivência do Sistema Operacional e de serviços vitais (Traefik, Authentik).
    - **Erro no Tailscale ACL (`invalid address`):** Tentativa de usar hostname `dockerhost-vpn` diretamente na chave `dst` do ACL gerou erro de sintaxe.
        - *Solução:* Ajustado para utilizar o padrão de notação de rede e curingas suportados: `*:*` para acesso ao próprio nó e `10.10.0.0/16:*` para liberação administrativa total das VLANs.
    - **Comportamento de Memória e SWAP:** Durante o boot e geração agressiva das chunks iniciais do mundo, o uso de RAM da VM saltou de 3.3GB para 5.5GB, acionando fortemente o SWAP do Debian (atingindo 87% da partição de 2GB).
        - *Conclusão:* Comportamento perfeitamente normal e esperado. A JVM consumiu seu heap de 3GB + non-heap, e o Kernel alocou *Page Cache* agressivamente para otimizar o I/O do SSD durante a gravação das chunks, jogando processos inativos para o swap temporariamente. O *Hard Limit* de 4GB do container evitou perfeitamente um *OOM Kill*. *(Nota para o futuro: Avaliar o incremento de RAM da VM DockerHost se mais containers pesados forem adicionados).*

## 2026-03-24
**Status:** ✅ Sucesso (Conexão Cabeada do Desktop e Hardening L2)

**Foco:** Provisionamento da rede cabeada para o Desktop (VLAN 20) e auditoria geral de segurança no Switch TP-Link SG2008.

- **Dívida Técnica:** O Desktop de uso pessoal dependia do Wi-Fi para acessar a rede (SSID Homelab_Trusted). Embora o AP suporte Wi-Fi 6, a placa do Desktop é antiga, gerando latência alta sob estresse e instabilidade em conexões com o server/internet.
- **Implementação Física:** Cabo de rede (Cat6 Furukawa Sohoplus 100% Cobre 10 Metros) passado do Desktop até a Porta 3 do Switch TP-Link (Modelo SG2008 v4.0).
- **Hardening e Configuração do Switch L2:**
  - **Reset de Fábrica:** Como a senha de gerência do switch foi perdida, procedeu-se com o Hard Reset (mantendo o funcionamento da rede via OPNsense Router-on-a-Stick restabelecido posteriormente).
  - **Reconfiguração de VLANs (802.1Q):**
    - `VLAN 1 (System)`: Removida a porta 3 para evitar bypass de firewall.
    - `VLAN 20 (TRUSTED)`: Proxmox (P1) e AP (P2) configurados como *Tagged*. Desktop (P3) configurado como *Untagged* com PVID 20.
    - `VLAN 50 (IOT)`: Reconfigurada em P1 e P2 (*Tagged*).
  - **Proteção L2 e QoS:**
    - **Spanning Tree (STP):** Modo alterado de legado para **RSTP** e ativado globalmente e em todas as portas físicas (P1 a P8) para proteção contra loops.
    - **Loopback Detection:** Habilitado com modo *Auto-Recovery* em todas as portas físicas.
    - **Multicast:** Ativado **IGMP Snooping v3** (Fast Leave e Querier) globalmente e restrito às VLANs 20 e 50 para mitigar flood de pacotes (Chromecast/AirPlay).
    - **Visibilidade:** Ativado **LLDP** (Tx/Rx) para mapeamento futuro com o Proxmox.
  - **Auditoria de Acesso (Ação Corretiva):** - Desativado serviço Telnet (texto plano) que estava ativado por padrão.
    - Ativado serviço SSH para gerência com imposição de criptografia apenas para **Protocol V2** (V1 depreciado/vulnerável desativado).
  - **Backup:** Configuração final do switch (L2/VLANs/Security) exportada e salva no repositório local (`.cfg`) para garantir rápida restauração (RTO minimizado) em caso de falha de hardware.
- **Validação:** Desktop obteve IP via DHCP do OPNsense (`10.10.20.103`). Teste de ping para `8.8.8.8` indicou melhoria drástica de estabilidade: `mdev` caiu de `20.639 ms` (com picos de 145ms no Wi-Fi) para incríveis `0.333 ms` na rede cabeada Gigabit Full Duplex.

## 2026-03-22
**Status:** ✅ Sucesso (Soberania de DNS e Zero Leaks)

**Foco:** Transição para DNS Recursivo (Unbound), eliminação de DNS público e ativação estrita de DNSSEC.

- **Dívida Técnica:** A infraestrutura e o AdGuard dependiam de DNS públicos (Cloudflare `1.1.1.1`, Quad9, Google `8.8.8.8`). Isso criava vazamento de metadados de navegação e quebrava o princípio de Soberania. As VLANs de infra (MGMT, SERVER, SECURE) usavam `1.1.1.1` como rota de escape, vazando telemetria interna.
- **Estratégia Adotada:**
  1. O **Unbound** no OPNsense foi configurado como Resolver Recursivo Puro (sem forwarding), indo buscar IPs diretamente nos *Root Servers* da internet.
  2. O **AdGuard** (Proxmox e RPi) teve seus upstreams e fallbacks limpos, apontando estritamente para o OPNsense (`:53`).
  3. O **DHCP** das VLANs de infraestrutura (10, 30 e 40) foi corrigido para entregar apenas o IP do gateway local, forçando os servidores a usarem o Unbound nativo, eliminando a dependência do AdGuard sem comprometer a privacidade.
- **Hardening Adicional:** O DNSSEC foi ativado no OPNsense para prevenir *Cache Poisoning* e ataques MitM.
- **Validação:** Teste de *DNS Leak* realizado com sucesso. Apenas o ASN do provedor local (ISP) é detectado pela internet, provando que NENHUMA Big Tech intermediária está mapeando o tráfego.

## 2026-03-20
**Status:** ✅ Sucesso (Controle de Blast Radius)

**Foco:** Implementação de limites de recursos no Docker (Cgroups) e habilitação de métricas de Saturação.

- **A Dívida Técnica:** Os containers rodavam sem restrições de CPU/RAM. Isso impedia o Grafana de calcular a Saturação (USE Method) e criava um risco arquitetural: um "vizinho barulhento" (ex: Syncthing fazendo hash de arquivos grandes ou Loki ingerindo burst de logs) poderia acionar o OOM Killer do host e derrubar serviços críticos como Traefik e Authentik.
- **Estratégia Adotada:** Em vez de limitar todos os containers e arriscar instabilidade por micro-management, apliquei apenas nos ofensores (PLG Stack + Syncthing).
- **Validação via Cgroups (`docker stats` / `docker inspect`):**
  - **Prometheus:** Média de ~187MB -> Limite de 1.2GB (Margem alta projetada para suportar a compactação pesada de TSDB em disco).
  - **Loki:** Média de ~105MB -> Limite de 500MB (Margem para suportar burst repentino de logs).
  - **Alloy:** Média de ~66MB -> Limite de 300MB.
  - **Syncthing:** Média de ~44MB -> Limite de 700MB e 1 vCore inteiro (Para garantir performance de I/O em arquivos massivos sem travar a VM).
- **Resultado:** Os serviços base permanecem intocados, garantindo que eu nunca fique "trancado para o lado de fora". Os coletores e indexadores agora operam numa "caixa de areia" com teto rígido validado diretamente no Kernel.

## 2026-03-19
**Status:** ✅ Sucesso (Eliminação de Dívida Técnica Crítica)

**Foco:** Correção estrutural do provisionamento de Datasource no Grafana (UID determinístico).

- **A Dívida Técnica (UID Aleatório):**
  - *Problema:* O Grafana gerava um UID aleatório para o datasource do Prometheus (ex: `dfa44v3b15a80b`).
  - *Impacto:* Os dashboards dependiam de um `sed` para injetar esse UID nos JSONs, quebrando o princípio da imutabilidade/reprodutibilidade. Em caso de perda do volume, um novo UID seria gerado e todos os painéis falhariam silenciosamente.
- **Correção:**
  - Criação do arquivo `datasources/prometheus.yml` forçando um UID fixo e semântico (`uid: prometheus-homelab`).
  - Refatoração de todos os dashboards (dashboards/*.json) para apontar para esse identificador imutável.
- **Resultado:**
  - Stack de observabilidade agora **100% efêmera e reprodutível.
  - Eliminação total de scripts de `find-and-replace`.
  - Garantia de integridade em cenários de Disaster Recovery.

## 2026-03-18
**Status:** ✅ Sucesso (Teste de DR, Correção de Rede e Adições ao Syncthing)

**Foco:** Validação de Shutdown da OrangeShadow, Fix do CrowdSec e Otimização do Syncthing.

- **CrowdSec Crash Loop:**
  - *Sintoma:* Erro de DNS `network is unreachable` para `10.10.30.5`.
  - *Causa:* Race condition no boot faz o Docker perder a rota da rede interna do container.
  - *Correção:* `docker compose up -d --force-recreate` em `/opt/security` resolveu o problema instantaneamente, recriando as interfaces lógicas e o pareamento com o Bouncer.
- **Auditoria de Disaster Recovery (OrangeShadow):**
  - Realizado *Cold Boot* forçado via GUI do Proxmox para medir o tempo real de shutdown do servidor com os bancos de dados criptográficos ativos.
  - *Tempo Medido:* 77 segundos (Graças aos limites de RAM de 3GB no Cgroups, o flush da memória pro disco SSD foi rápido).
  - *Validação:* Logs do `bitcoind` e `monerod` subiram limpos. Swap zerado. Nenhuma corrupção no LevelDB ou LMDB.
- **Ajuste Matemático do Nobreak:**
  - O script `/usr/local/bin/ups-kill.sh` no Raspberry Pi foi corrigido para evitar o corte prematuro de energia.
  - *Cálculo:* 77s (Shutdown real medido) + 63s (Margem de segurança contra variações de I/O) = `sleep 140`. Garante a morte do hardware elétrico apenas 140s após o alerta de bateria baixa.
- **Expansão e Otimização do Syncthing:**
  - *Expansão:* Integradas as pastas de "Screen Recordings" e "Voice Recordings" do celular M55 ao servidor, mantendo a topologia "Send & Receive".
  - *Tuning de I/O:* Identificada falha de configuração padrão onde o "File Pull Order" estava como "Random" (Aleatório). Isso causa picos de IOPS e fragmentação desnecessária na memória UFS do Android e no SSD do servidor em topologias *Hub-and-Spoke*.
  - *Ação:* Alterado globalmente nos três nós (DockerHost, Arch Linux e Samsung M55) o "File Pull Order" para **Oldest First** (Mais antigos primeiro), garantindo leitura/escrita sequencial amigável aos discos.

## 2026-03-12
**Status:** ✅ Sucesso Absoluto (Soberania Financeira Concluída).

**Foco:** Conclusão do IBD do Monero, Transição para Darknet (Fase 4), Hardening de RPC e Deploy do Client (Feather Wallet).

### A Matemática do Sucesso (Benchmark IBD Monero)
- O *Initial Block Download* (IBD) do Monero baixou e verificou mais de 3.628.000 blocos em **11 horas e 30 minutos** (das 20:44 de 11/03 às 08:12 de 12/03).
- **Fatores de Êxito:** A estratégia de entregar 10GB de RAM ao banco LMDB e forçar gravações assíncronas em lotes de 250MB (`db-sync-mode=fast:async:250000000bytes`) no SSD Samsung obliterou o gargalo crônico do Monero. A mensagem de log `You are now synchronized with the network` oficializou o fim do modo de alto esforço.

### Cirurgia no Metal: Downgrade para Fase 4 (Produção)
- Com ambos os nós (BTC e XMR) sincronizados, a VM 107 (`OrangeShadow`) não precisa mais de 16GB de RAM. A máquina foi desligada com flush gracioso dos bancos de dados e a RAM foi cortada para **8GB** via hypervisor Proxmox.
- **Rebalanceamento de Cgroups (Systemd):**
  Para evitar que o *OOM Killer* destruísse a máquina, a RAM foi matematicamente fatiada nos serviços:
  - `bitcoind.service`: Subiu de 2G para `3G`.
  - `monerod.service`: Caiu de 10G para `3G`.
  - `electrs.service`: Caiu de 10G para `1G`.
  - OS / Tor: `~1G` livre.
  - A telemetria pós-reboot (`free -h`) confirmou uso estável de 1.4GB, com 6.3GB em cache e 0B de Swap, rodando de forma lisa e fria.

### Conectando na Darknet (Monero)
- O `bitmonero.conf` foi reescrito para o estado de camuflagem total.
- **Dandelion++ via Tor:** Configurado `tx-proxy=tor,127.0.0.1:9050,10` para broadcast de transações e `proxy=127.0.0.1:9050` para sincronização.
- **Nó Cego:** Diferente do Bitcoin, optei por manter `in-peers=0`. Não há um *Hidden Service* publicado para receber conexões P2P, garantindo anonimato direcional absoluto para mitigar qualquer vazamento de IP no repositório.

### O Incidente do RPC Bind e a Defesa do Monero
- **Objetivo:** Expor a porta 18081 para a VLAN 20 (Arch Linux) conectar a Feather Wallet (`rpc-bind-ip=0.0.0.0`). Liberada a porta no UFW (`10.10.0.0/16`).
- **Crash Loop:** Ao reiniciar o daemon, ele falhou criticamente com a exception: `--rpc-bind-ip permits inbound unencrypted external connections`.
- **Análise:** O Monero é defensivo por design. Ele se recusa a abrir a porta em IP público/LAN sem SSL, assumindo que será hackeado. Como a segurança L3 já é garantida pelo firewall OPNsense e pelo isolamento em VLANs (`10.10.x.x`), adicionei a flag de força bruta `confirm-external-bind=1`. O daemon acatou a exceção e subiu o RPC.

### Instalação do Client (Feather Wallet) e Supply Chain
- **A Queda do AUR:** O pacote `feather-wallet-bin` desapareceu/quebrou no AUR do Arch Linux.
- **A Alternativa (AppImage):** Migrei para o formato AppImage oficial portátil.
- **Validação de Assinatura (PGP):**
  - Chave importada: `curl https://featherwallet.org/files/featherwallet.asc | gpg --import`.
  - Fingerprint validado: `8185 E158 A333 30C7 FD61 BC0D 1F76 E155 CEFB A71C`.
  - Assinatura do binário verificada (`Good signature`), evitando riscos de software malicioso.

### Privacy Hardening na Interface (Feather)
Durante o setup, a Feather Wallet tentou vazar metadados por conta de "configurações amigáveis" nativas:
1. **O Loop do Tor LAN:** A Feather forçava o roteamento pelo Tor local (`127.0.0.1:9050`). O Tor não roteia IPs RFC 1918 (VLAN 30 - `10.10.30.20`), o que causou falha de conexão ("Disconnected"). Solução: Roteamento de Proxy alterado para `None`.
2. **Ping a Terceiros:** A opção de Websocket foi desmarcada para impedir que o IP físico do Arch consultasse o preço do XMR em servidores centrais.
3. **Block Explorer:** O explorador público (xmrchain.net) foi alterado para um endereço `.onion`.
- **Aperto de Mão Final:** A carteira Polyseed (16 palavras) foi criada. O ícone de rede cravou no verde (`Synchronized`) com leitura imediata do Daemon local na porta 18081. A Soberania Total (Fase 4) foi oficialmente atingida.

## 2026-03-11
**Status:** ✅ Sucesso (IBD do Monero em Andamento).

**Foco:** Início da Fase 3 (Implementação do Nó Monero e Otimização Lógica).

### Engenharia de Software e Gestão de Versão
- **Ameaça da Versão Obsoleta:** O plano original previa a instalação da v0.18.3.4. Uma auditoria de última hora no repositório do *Monero Project* identificou que a versão estável atual é a **v0.18.4.6** (lançada em 04 de março de 2026). O download foi abortado e a versão atualizada foi baixada.
- **Supply Chain:** O *checksum* SHA256 do binário validou matematicamente contra as assinaturas oficiais do projeto (Arquivo não comprometido).

### Crash Loop Inicial (Evolução do Código)
- **Sintoma:** O `monerod` entrou em falha imediata após a inicialização.
- **Diagnóstico Forense:** O log do daemon reportou `Unrecognized option 'disable-rpc-login'`. A arquitetura do Monero atualizou o protocolo de segurança local, inferindo proteção por padrão quando vinculado ao IP de loopback (`127.0.0.1`), tornando a flag obsoleta e bloqueante.
- **Solução:** Arquivo `bitmonero.conf` retificado.

### Gerenciamento de Carga (Hypervisor vs Kernel)
- O nó do Bitcoin teve sua restrição de Kernel ampliada. O Systemd agora o limita a `MemoryMax=2G`, liberando o fôlego necessário na RAM (`10G`) para suportar as gravações assíncronas em lotes de 250MB do banco de dados LMDB do Monero.
- A sincronização (IBD) foi iniciada com sucesso em Clearnet, consumindo blocos do ano de 2014 a uma velocidade extrema na interface de disco Passthrough. O sistema aguarda agora o fim orgânico desse processamento nos próximos horas/dia.

## 2026-03-10
**Status:** ✅ Sucesso (Integração End-to-End).

**Foco:** Implementação do Client (Sparrow Wallet), Supply Chain Security e Hardening de Privacidade.

### A Batalha do Supply Chain (Confiança Matemática)
- **Risco:** Instalar softwares financeiros (Carteiras) via repositórios mantidos por terceiros (AUR por exemplo) abre vetor para injeção de malware roubador de chaves.
- **Defesa (PGP):** Antes da instalação, a chave pública do desenvolvedor principal (Craig Raw) foi importada via Keybase e seu *fingerprint* validado (`D4D0 D320 2FC0 6849 A257 B38D E946 1833 4C67 4B40`). O comando `yay` foi instruído a validar o `.tar.gz` assinado antes da descompactação.

### Hardening de Privacidade (A Armadilha do Mempool.space)
- **O Problema:** Por padrão, o Sparrow Wallet "vaza" a identidade de rede. Ele usa o `mempool.space` público para consultar o preço das taxas de rede e visualizar blocos, vinculando o IP físico da operadora (ISP) ao interesse na blockchain.
- **Solução:** Nas configurações gerais do Sparrow (`File -> Preferences`), a fonte de taxas (Fee Rates Source) foi alterada para `Server` (apontando as consultas para a própria VM `OrangeShadow`). O *Block Explorer* foi silenciado. Consultas FIAT (Coingecko) foram mantidas por não transmitirem dados criptográficos de conta.

### Conexão e O "Aperto de Mão"
- A conexão `Private Electrum` foi estabelecida sem TLS (visto que a rede local VLAN 20 -> VLAN 30 já é um conduíte confiável) na porta `50001`.
- **Telemetria:** O Sparrow retornou `Batched RPC enabled` e conectou ao `electrs 0.11.1`. Os blocos da mempool exibidos na aba de envio agora são alimentados em tempo real pelo meu próprio hardware.

### Criação da Sandbox (Arquitetura de Cofres)
- **Escala de Paranoia:** Foi definido que a carteira criada hoje (Software Wallet nativa) operará como uma **Sandbox (Hot Wallet)** para aprendizado. Em cenários de produção futuros para reserva de valor, será exigida a implementação de Airgapped Cold Storage (ex: SeedSigner) ou uso amnésico via Tails OS.
- **Protocolo de Criação:** A semente BIP39 de 24 palavras foi gerada off-screen e registrada/armazenada de forma segura.
- **Resultado Final:** A carteira importou o `xpub` (Master Public Key) e o nó `OrangeShadow` varreu os 750GB de disco em milissegundos via índice RocksDB, confirmando a inexistência histórica de UTXOs atrelados à chave. Soberania alcançada.

## 2026-03-09
**Status:** ✅ Sucesso (Nó Público Onion e Indexação em Andamento).

**Foco:** Abertura do Perímetro Tor (Inbound) e Engenharia de Compilação do Electrs (Fase 2).

### O Risco do "Erro Fatal do GitHub" (Segurança P2P)
- **O Dilema:** Para o nó do Bitcoin ser um cidadão útil e validar/enviar blocos, ele precisa aceitar conexões (Inbound). O padrão da comunidade é definir o parâmetro `externalip=xyz.onion` no `bitcoin.conf`.
- **A Falha de OPSEC:** Como minha infraestrutura segue o paradigma *Infrastructure as Code* (GitOps), commitar um arquivo com o endereço onion exato no GitHub vincularia imediatamente minha identidade digital (DevOps) ao nó na Darknet, quebrando o princípio básico de anonimato.
- **A Solução (Tor Control API):**
  - Habilitei as diretrizes `ControlPort 9051` e `CookieAuthentication 1` no `/etc/tor/torrc`.
  - Inseri o usuário do sistema (`fajre`) no grupo `debian-tor` para permitir a leitura do cookie criptográfico.
  - No `bitcoin.conf`, apliquei `listen=1`, `listenonion=1` e `discover=1`.
  - **Resultado:** O Bitcoin Core conversou com o Daemon do Tor, negociou a criação de um *Hidden Service* em background, e publicou-se na rede. O comando `bitcoin-cli getnetworkinfo` retornou o endereço `.onion` na porta 8333 com sucesso absoluto. Zero rastros no Git.

### Compilação (Electrs vs Debian Trixie)
- **Necessidade:** O Bitcoin Core armazena blocos, mas não é um banco de dados pesquisável por endereços. O Electrs (Rust) atua como tradutor para a carteira Sparrow. A exigência de segurança (Supply Chain) forçou a compilação local (sem binários pré-compilados de terceiros).
- **Incidente 1 (Crash de API JSON):** A versão estável (tag `v0.10.4`) do Electrs compilou perfeitamente em ~8 minutos. Porém, ao iniciar, entrou em *Crash Loop* (Erro: `JSON error: invalid type: sequence, expected a string`).
  - *Causa Raiz:* O Bitcoin `v28.1` (Bleeding Edge) alterou a estrutura da resposta do RPC `localaddresses` de string para array (sequence). O Electrs legado quebrou.
  - *Roll-Forward:* Mudei a branch git do Electrs para a `master` para pegar as atualizações de API mais recentes.
- **Incidente 2 (O labirinto do Clang/LLVM):** Durante a recompilação da `master`, o script falhou criticamente no pacote `rust-rocksdb` (Erro: `couldn't find any valid shared libraries matching: ['libclang.so']`).
  - *Causa Raiz:* O script do Rust não encontrou o caminho da biblioteca dinâmica C++ no Debian Testing (que a instala como `libclang-19-dev` em diretórios específicos versionados).
  - *Solução:* Instalação forçada do pacote base e injeção do caminho correto via variável de ambiente antes da compilação: `export LIBCLANG_PATH=$(llvm-config-19 --libdir)`.
- **Vitória:** O binário otimizado da versão `0.11.1` foi gerado (3m 18s).
- **Ignição:** O serviço `electrs.service` foi iniciado (com colete de força `MemoryMax=10G`). Os logs mostraram que a comunicação com o Bitcoin via `.cookie` funcionou perfeitamente e o Electrs começou a engolir os blocos da rede a velocidades extremas. A indexação completa no SSD SATA vai durar a madrugada.

## 2026-03-08 (Parte 2)
**Status:** ✅ Sucesso (IBD Concluído e Camuflagem).

**Foco:** Finalização da Sincronização do Bitcoin e Transição para a Rede Tor.

### A Matemática do Sucesso (Benchmark do IBD)
- O *Initial Block Download* (IBD) processou toda a história do Bitcoin (de 2009 até o bloco 939.920) em aproximadamente **21 horas**.
- **Fatores de Êxito:** A estratégia de utilizar um SSD com cache DRAM (Samsung 870 EVO) aliado à alocação de 11GB de RAM (`dbcache=11000`) foi impecável. No pico, o nó segurou mais de 63 milhões de UTXOs em ~8.6 GB de RAM antes de consolidar no disco, evitando o *thrashing* da controladora SATA.

### O Grande Flush e a Transição (Fase 2)
- Executei o `systemctl stop bitcoind`. O tempo de *flush* dos dados da RAM para o disco levou vários minutos, validando a necessidade do parâmetro `TimeoutStopSec=600` que configurei no Systemd ontem para evitar corrupção por encerramento forçado.
- **Redução de Pegada:** Com o banco de dados atualizado, o nó não precisa mais devorar a memória do servidor. O `dbcache` foi estrangulado para `512` (MB), devolvendo mais de 10GB de RAM para o Sistema Operacional (que serão usados pelo Electrs).

### Camuflagem (Tor)
- O pacote `tor` já havia sido instalado no Debian. O teste via `curl --socks5` confirmou a saída anônima.
- O `bitcoin.conf` foi alterado para operar **estritamente via Tor** (`onlynet=onion`). A máquina sumiu da Clearnet.
- **Validação:** Ao reiniciar, os logs reportaram `Leaving InitialBlockDownload` e as novas conexões `block-relay-only` passaram a ocorrer perfeitamente através de *peers* Onion (v2/v3). O motor base está concluído.

## 2026-03-08
**Status:** ✅ Sucesso (IBD Iniciado).

**Foco:** Ignição do Nó Bitcoin (OrangeShadow - VM 107), Engenharia de Throttling e Correção de Backup.

### Desilusões Arquiteturais e Realismo Físico
- **O Mito do "All-in-One":** Descartei a ideia de rodar Mempool.space e Lightning Network no servidor. A memória RAM (8GB alvo para produção) não comporta Redis e MariaDB operando simultaneamente com o motor do Monero e Bitcoin sem causar *starvation*. A LN exige *inbound liquidity* e *clearnet* de baixa latência, incompatíveis com roteamento Tor. O servidor será estritamente uma caixa-forte *On-Chain*.
- **A Armadilha da Hot Wallet (`wallet.dat`):** O plano original previa backupear a carteira no Backblaze B2. Inaceitável. O Bitcoin Core foi reconfigurado com `disablewallet=1`. O nó é agora um validador cego. A seed será gerada offline (Tails OS) e o client (Sparrow no Arch Linux) terá apenas a chave pública (xpub).

### Blindagem de Hypervisor (Proxmox Cgroups)
Para impedir que a validação matemática intensa (ECDSA/Schnorr) cause um ataque DoS contra os nós críticos (DockerHost, OPNsense), apliquei limites diretamente no metal via CLI:
- **CPU:** `qm set 107 --cpuunits 512` (reduz o peso no scheduler do Proxmox à metade do padrão) e `--cores 4` (teto físico).
- **I/O de Disco:** `qm set 107 --scsi1 file=/dev/disk/by-id/[...],iothread=1,mbps_wr=250,mbps_rd=400,aio=threads,discard=on,backup=0`. Limitou-se a escrita a 250 MB/s para que a controladora da placa-mãe não trave os SSDs NVMe do pool ZFS principal.

### Erros, Falhas e Soluções (Post-Mortem do Setup)
- **Erro de Traffic Shaping (Network):** Ao tentar limitar a rede a 15MB/s (`rate=15` no `net0`), o Kernel do Proxmox disparou alertas do algoritmo *sch_htb* (`quantum of class 10001 is big`). Limitar a placa virtual L2 estrangulou a comunicação com o Gateway e DNS. **Solução:** Removi o limite físico (`qm set 107 --net0 virtio=...,bridge=vmbr0,tag=30`) e deleguei o controle de rede à aplicação (`maxconnections=40` no `bitcoin.conf`).
- **Engano de Hot-Plug de SCSI:** Tentei injetar os parâmetros assíncronos (`aio=threads`) com a VM rodando. O Proxmox registrou a mudança em laranja (Pending Change), pois KVM não altera o pipeline de disco root a quente. **Solução:** Foi necessário o ciclo elétrico bruto (`qm stop 107` seguido de `qm start 107`). Um simples reboot via Linux não injetaria a alteração do Hypervisor.
- **Erro Estratégico de P2P:** Iniciei com `listen=1`. Isso permitiu conexões de entrada. A máquina começou a ler do disco e servir blocos históricos para outros nós, gastando I/O que deveria ser da própria validação. **Solução:** Alterado para `listen=0` (Modo Parasita) temporariamente até o fim do IBD.

### Validação de FS e Instalação
- Verifiquei o `/etc/fstab` e constatei que o disco do blockchain já havia sido montado com a diretriz `noatime`. Isso evitou a escrita contínua de metadados (*Access Time*) cada vez que um bloco de 2MB é lido, salvando ciclos cruciais de IOPS.
- Instalação via binários pré-compilados (`v28.1`) verificados por `sha256sum`.

### Correção Crítica de Backups (Restic)
O arquivo `setup_backup.yml` do Ansible instruía o backup da pasta blockchain inteira e do `wallet.dat`. Isso subiria 700GB de dados públicos inúteis para a nuvem e, pior, poderia vazar chaves privadas. **Solução:** O Restic na OrangeShadow foi reescrito para fazer o backup **estritamente** da inteligência do nó (`bitcoin.conf`, `bitcoind.service`), ignorando `/opt/blockchain`.

## 2026-03-07
**Status:** ✅ Sucesso

**Foco:** Implementação de Web Drive (File Browser) sobre o Syncthing.

- **O Problema da Autenticação via Proxy:** Abandonei a tentativa de usar a autenticação via injeção de Headers (`X-Authentik-Username`) no File Browser. Essa integração é historicamente frágil e sujeita a bugs que quebram o acesso à menor alteração de roteamento.
- **Solução:** Adoção de autenticação dupla isolada. O Authentik atua como porteiro rígido no Traefik, enquanto o File Browser usa seu próprio banco (`filebrowser.db`) com credenciais geradas randomicamente no primeiro boot (capturadas via `docker logs`) e substituídas por senhas fortes no cofre.
- **Trade-off do Syncthing:** Para que a edição via interface web funcione de forma bidirecional, fui forçado a abrir mão do modo "Receive Only" do servidor, voltando as pastas para "Send & Receive". O servidor deixa de ser apenas um cofre de leitura e volta a ser um nó ativo na alteração de dados.

## 2026-03-02
**Status:** ✅ Sucesso (Validação Empírica e Engenharia de Resiliência)

**Foco:** Implementação do NUT Primary (Master) no Edge Node (RPi), Disaster Recovery e Radar de Energia L3 (Prometheus/Grafana).

### Validação de Autonomia e Firmware (Intelbras Gamer Ultimate)
- **Teste:** Simulação de blecaute físico com carga (~165W).
- **Resultados Empíricos:** - O Nobreak levou exatos **49 minutos** para drenar a bateria de 100% até 48%.
  - O parâmetro `override.battery.charge.low = 50` forçou com sucesso o firmware a emitir o alerta `OB DISCHRG LB` (Low Battery).
  - O firmware do UPS **ignora** comandos de atraso via software (`offdelay`). O tempo de corte `ups.delay.shutdown` é fixado rigidamente em 20 segundos pela fabricante (CyberPower/Intelbras).
  - **Fail-Safe do Firmware:** O Nobreak ignora comandos de `shutdown/killpower` se estiver recebendo energia da rua (`OL` - On Line). O desligamento só é acatado em modo bateria (`OB`).

### Limitação do fluxo padrão de shutdown do NUT sob systemd (Debian 13)
- **Incidente:** Durante o teste de *Forced Shutdown* (`upsmon -c fsd`), o RPi desligou, mas o Nobreak e o restante continuaram ligados indefinidamente.
- **Diagnóstico (Fluxo de Shutdown):** Durante o FSD (`upsmon -c fsd`), o Raspberry Pi encerrava o sistema operacional corretamente, mas o comando final `load.off` não era entregue ao UPS.
- **Análise:** O fluxo padrão do NUT sob `systemd` executa o `SHUTDOWNCMD` em uma fase tardia do processo de desligamento. Nessa etapa, o driver USB (`usbhid-ups`) já pode ter sido encerrado pelo gerenciador de serviços, impedindo a transmissão confiável do comando de corte físico ao Nobreak.
- **Conclusão:** O comportamento observado não indica falha de firmware, mas sim limitação operacional do encadeamento NUT + systemd durante o shutdown.
- **Solução:** Desenvolvido o script `/usr/local/bin/ups-kill.sh` que utiliza força bruta (`pkill -9 usbhid-ups`) para soltar a porta USB fora da árvore do systemd, envia o comando de morte ao Nobreak (`upsdrvctl shutdown`), e só então invoca o `shutdown -h now` do RPi.

### Teste Destrutivo Final
- Executado novo FSD no RPi com o Nobreak desconectado da tomada (com energia da bateria) (via bypass L2 no Switch). (O Proxmox foi desligado para evitar corrupção durante os testes)
- O RPi aguardou os tempos de sync (20s), iniciou o script customizado, apagou o sistema operacional e, 10 segundos depois, o Nobreak estalou o relé e cortou a energia das tomadas, blindando a infraestrutura. O sistema voltou à vida automaticamente ao retornar a energia da rua.

### Cálculo Empírico da Janela de Evacuação do ZFS
- **O Problema:** A arquitetura padrão do NUT via `HOSTSYNC` é falha no Proxmox (Debian), pois o `systemd` mata a rede e o `nut-client` precocemente durante o shutdown. Isso faz o RPi achar que o servidor já desligou, enviando o comando de corte físico (load.off) enquanto o Proxmox ainda está gravando no ZFS.
- **Medição Real:** Executado desligamento cronometrado do Proxmox via GUI com todas as VMs atuais (OPNsense, AdGuard, Vault, DockerHost). Tempo total até o poweroff físico: cerca de **1 minuto e 23 segundos (83s)**.
- **Engenharia de Atraso:** Implementado um `sleep 130` incondicional no script `/usr/local/bin/ups-kill.sh` do RPi, adicionando 47s de margem sobre o tempo medido.

### Validação Definitiva de Disaster Recovery (Teste de FSD Risco Zero)
- **Metodologia:** Executado teste prático do gatilho *Forced Shutdown* (`upsmon -c fsd`). Para proteger o ZFS caso a matemática falhasse, o cabo de energia do Proxmox foi temporariamente movido do Nobreak para a parede, mantendo o RPi, Switch, AP e Modem no Nobreak em modo bateria.
- **Cronologia Empírica Registrada:**
  - `0s`: Disparo do gatilho FSD no RPi (Modo Bateria).
  - `73s`: Proxmox concluiu o ACPI shutdown graciosamente e apagou totalmente o hardware.
  - `155s`: Nobreak executou o estalo do relé e o corte físico de carga.
- **Veredito:** A janela incondicional funcionou com precisão milimétrica. O servidor desligou totalmente e o sistema obteve **82 segundos de sobra** antes do corte elétrico. Arquitetura de Disaster Recovery homologada. Hardware retornado para as tomadas corretas.

### Radar de Energia e Telemetria (A "Matrix" do Prometheus)
- **O Desafio do Exporter:** O `nut-exporter` (v3.x) desvia do padrão da comunidade. Em vez de exportar métricas na raiz `/metrics`, ele exige um caminho customizado `/ups_metrics` e a passagem do parâmetro da máquina via query string `?ups=intelbras`. Sem isso, as métricas perdem suas *labels*, quebrando o Grafana e as regras de alerta.
- **A Armadilha do Relógio (Evaluation Interval):** - *Sintoma:* Durante o teste de queda, o status no Grafana atualizava rápido, mas o Ntfy demorava mais de 2 minutos para apitar.
  - *Causa:* O Prometheus possui dois relógios. O `scrape_interval` (ir buscar o dado) estava em 15s, mas o `evaluation_interval` (rodar a regra para ver se é caso de alerta) estava no padrão de 1m. O alerta ficava travado em `PENDING` aguardando o próximo ciclo.
  - *Solução:* Sincronizado o `evaluation_interval` para `15s` no `prometheus.yml`. Alertas crtíticos agora mudam para `FIRING` no tempo exato, somados ao `group_wait` de 30s do Alertmanager.
- **Exposição da Interface de Diagnóstico:** O Prometheus foi conectado à rede `proxy` e exposto via `prometheus.home` (com o Authentik) para permitir a visualização em tempo real das transições de estado de alertas (`Inactive -> Pending -> Firing`), o que foi vital para o troubleshooting.
- **Dashboard Vacinado:** O arquivo JSON nativo do Grafana para o NUT depende de uma variável de ambiente na interface gráfica. Como utilizo *Dashboard as Code* (provisionamento mudo), foi necessário rodar um `sed` para injetar no código-fonte do painel o UID estático do Prometheus (`dfa44v3b15a80b`), curando o erro crônico de "No Data / Datasource not found".

## 2026-03-01
**Status:** ✅ Sucesso (Otimização RF, Manutenção e Ergonomia)

**Foco:** Sintonia Fina de Wi-Fi 6 (Camada L1/L2), Ergonomia do UPS e Mitigação Térmica (RPi).

### Otimização de Rádio Frequência (Access Point TP-Link Omada)
- **O Problema (Física de Redes):** A rede `Homelab_Trusted` (5 GHz) apresentava degradação severa de sinal no quarto (-71 dBm, 130 Mbps), enquanto o roteador da ISP (2.4 GHz) entregava sinal forte. O AP estava operando com configurações de fábrica ("Auto"), limitando o uso do rádio 2.4 GHz e desperdiçando os recursos de multiplexação do Wi-Fi 6.
- **A Solução (RF Tuning "Enterprise"):**
  - **Band Steering (Smart Connect):** Habilitada a função `Prefer 5GHz`. O AP agora emite o mesmo SSID em ambas as bandas (2.4 GHz e 5 GHz). Dispositivos próximos usam 5 GHz (alta velocidade); quando afastados, sofrem *Roaming* forçado e transparente para 2.4 GHz (alta penetração).
  - **Largura de Canal (Channel Width):**
    - **2.4 GHz:** Forçado para `20MHz` (Canal 6 fixo). Reduz drasticamente a captação de interferência de vizinhos (Bluetooth, micro-ondas), atuando como um "laser" para atravessar paredes com estabilidade.
    - **5 GHz:** Forçado para `80MHz` (Canal Auto). Garante o *throughput* máximo (Gigabit) para conexões na sala.
  - **OFDMA (O Superpoder do Wi-Fi 6):** Habilitado explicitamente nas abas *More Settings*. Permite a transmissão simultânea de pacotes para múltiplos clientes (Notebook + Mobile + IoT), reduzindo drasticamente a latência de rede.
  - **Gerenciamento L2:** Fixado o IP administrativo do AP para `192.168.1.10`, apontado o NTP para `a.ntp.br` e realizado backup a frio da configuração (`.bin`), que foi salvo com segurança.
  - **Resultado Empírico:** O *rx bitrate* no Arch Linux (quarto) subiu para `260.0 MBit/s` (Sinal -68 dBm no 5Ghz) com quedas controladas e a rede 2.4 GHz passou a entregar um sinal massivo de qualidade 77.
- **Sanitização de Espectro (Isolamento):** Solicitado ao suporte da ISP (Unifique) o desligamento total da emissão Wi-Fi do modem deles. O Homelab agora é a única infraestrutura com autoridade sobre o espaço aéreo do apartamento.

### Ergonomia e Ambiente (UPS Intelbras)
- **Identidade Visual:** Alterado o LED frontal RGB nativo para a cor **Ciano** (segurando o botão por 2s), alinhando intencionalmente a estética do UPS com as ventoinhas padrão do gabinete do servidor (DeepCool CC560).

### Mitigação de Falha Mecânica (Edge Node)
- **O Incidente:** A ventoinha do case do Raspberry Pi começou a apresentar falhas de rotação e ruídos anômalos.
- **Decisão Arquitetural:** Em vez de substituir a peça e manter o risco mecânico/sonoro na sala, decidi validar a viabilidade técnica de operar o nó de borda de forma 100% passiva.
- **Validação (Stress Test):**
  - Desconectei a ventoinha fisicamente.
  - Submeti a CPU ARM a 100% de carga por 3 minutos usando o pacote `stress`.
  - Monitorei via `vcgencmd measure_temp`.
  - **Resultado:** A temperatura saltou do baseline (44°C) para o pico máximo de **78.8°C**. Logo após o fim do stress, a temperatura entrou em queda livre.
  - **Prova:** O comando `vcgencmd get_throttled` retornou `0x0`. Nenhuma degradação de clock ocorreu.
- **Conclusão:** A ventoinha foi retirada. A refrigeração passiva com os adesivos térmicos atende com folga as métricas de operação real. Log arquivado na pasta de assets.

## 2026-02-28
**Status:** ✅ Disaster Recovery & Networking

**Foco:** Resolução do isolamento L3 após migração física para Ibirama.

- **Incidente:** O modem da Unifique (ISP local) opera forçadamente na rede `192.168.1.0/24`. O homelab possuía a fundação de gerenciamento "hardcoded" em `192.168.0.0/24`.
  - *Resultado:* Servidor inacessível, RPi sem internet e bloqueio total por dependência cíclica ("Deadlock Ovo e Galinha": Sem internet -> sem VPN -> sem Dropbear -> sem Proxmox -> sem OPNsense para rotear -> sem internet).
- **Resolução (Bypass):**
  - Conexão física (cabo direto) entre o notebook (Arch) e a placa do gabinete do server, forçando um IP fantasma `192.168.0.10` na placa de rede para simular o ambiente antigo.
  - Acesso via SSH ao Dropbear no initramfs (`192.168.0.200`) e desbloqueio manual do FDE (LUKS).
- **Cirurgia de IP:**
  - **Proxmox:** Atualização do `/etc/network/interfaces` e `/etc/initramfs-tools/initramfs.conf` para o IP `192.168.1.200`. Reconstrução do bootloader executada com sucesso (`update-initramfs -u -k all`).
  - **RPi:** Acesso físico via NMTUI para alterar o IP estático e Gateway.
  - **Tailscale:** Atualização forçada da rota de sub-rede (`--advertise-routes=192.168.1.0/24`) e aprovação mandatória no painel admin para a VPN voltar a rotear pacotes, além de alterar o IP `.0.200` para `.1.200` no `acls.hujson` nas regras de controle de acesso da Tailscale.
  - **OPNsense (DNS Failover):** O escopo DHCP das VLANs (20 e 50) ainda apontava para o RPi antigo (`.0.5`). O IP do DNS Secundário foi atualizado para `192.168.1.5` para evitar quebra de resolução se o AdGuard (Primário) cair ou falhar.
- **Erros de Camada 2 (ARP & Conflito Lógico):**
  - O RPi (IP fixo `.5`) conflitou com o Access Point TP-Link, que recebeu o mesmo IP `.5` via DHCP do modem da operadora.
  - *Solução:* Desconectar o AP fisicamente, limpar o cache ARP no cliente Arch (`ip -s -s neigh flush all`), validar a comunicação com o RPi, e reconectar o AP (que foi forçado a solicitar um novo IP, pegando o `.10`).
- **Falso Positivo de Exposição (OPNsense):**
  - **Sintoma:** A GUI do OPNsense estava respondendo no IP da WAN (`192.168.1.9`) quando acessada de dentro da rede `Homelab_Trusted`.
  - **Diagnóstico:** Não era vazamento de Firewall (as regras WAN estavam corretas e bloqueando tráfego externo). Era um problema de *Binding*. A configuração "Listen Interfaces" estava como `All`, permitindo que o servidor web interno (Lighttpd) respondesse na WAN para pacotes originados internamente.
  - **Solução:** Restrição explícita em **Settings > Administration** para escutar apenas em `VLAN_10_MGMT` e `VLAN_20_TRUSTED`. Acesso bloqueado com sucesso nas demais interfaces. O IP real do firewall é o gateway da respectiva VLAN (ex: `10.10.20.1`).
- **Automação (Ansible & IaC):**
  - Busca recursiva (`grep -RIn "192\.168\.0\." .`) para alterar toda a documentação e configuração para `.1`.
  - **Falha de Playbook:** O playbook `hardening_rpi.yml` falhou na linha 143 (`'tailscale_auth_key' is undefined`) porque a variável não havia sido declarada para input. Adicionado o bloco `vars_prompt` para correção. Playbooks de monitoramento e RPi rodados com sucesso.
- **Erros Operacionais e Lições Aprendidas:**
  - **Falso Positivo de Roteamento:** O Arch Linux perdeu a rota (`No route to host`) para o Proxmox (`.1.200`) mesmo com o Wi-Fi conectado na VLAN correta. Motivo: A interface ethernet `enp1s0f1` estava desconectada do cabo, porém ainda mantinha o IP `.1.10` amarrado estaticamente. O kernel tentava rotear pela placa morta. (Resolvido apagando o IP: `sudo ip addr del 192.168.1.10/24 dev enp1s0f1`).
- **Gestão de Versão:** Todo o conserto e adaptação da infraestrutura foi realizado na branch `fix/migracao-rede-ibirama` para um *Squash Merge* auditável na main.

## 2026-02-27
**Status:** ❌ Falha (Planejamento)

**Foco:** Mudança física de hardware.

- **A Ilusão do Plug & Play:** O hardware foi trazido e ligado. A premissa de que a infraestrutura seria agnóstica de localização caiu por terra devido à dependência de sub-rede estrita (`/24`) do Gateway ISP.
- *Lição:* Endereçamento IP manual na fundação garante segurança absoluta, mas pode destruir a portabilidade. Mudanças físicas as vezes exigirão refatoração manual de acesso de borda.

## 2026-02-26
**Status:** ✅ Sucesso (Validação de Hardware)

**Foco:** Teste de compatibilidade do Nobreak Intelbras Gamer Ultimate com o Linux (NUT).

- **Teste de Carga e Reconhecimento:** Após 24h de carga inicial, o equipamento foi conectado ao RPi isolado. O comando `lsusb` retornou `ID 0764:0601 Cyber Power System, Inc.`. Diferente da Ragtech e do NHS, a Intelbras usou um chipset padrão de mercado (OEM CyberPower), livrando-me de engenharia reversa ou possível nova devolução.
- **Troubleshooting de Driver:** O NUT falhou com `insufficient permissions on everything`. Motivo: O Linux atrelou o controlador USB ao usuário `root` (porque o nobreak foi conectado antes de instalar o pacote). Em vez de reiniciar, as regras foram recarregadas dinamicamente via `udevadm control --reload-rules && udevadm trigger`.
- **Telemetria:** O driver `usbhid-ups` comunicou-se com sucesso, retornando status `OL CHRG` e voltagens reais. O hardware é apto para produção.

## 2026-02-24
**Status:** ✅ Sucesso (Engenharia de Software & Qualidade)

**Foco:** Implementação de Pipeline de CI/CD Local (Pre-commit Hooks) e Sanitização do Código.

- **Adoção de Padrões de Mercado:**
    - Para evitar novos vazamentos de credenciais (como o incidente do Ntfy no passado) e garantir consistência no Ansible, implementei o framework **Pre-Commit**.
    - **O "Porteiro":** Agora, o `git commit` é interceptado por uma bateria de testes definida em `.pre-commit-config.yaml`. Se o código estiver "sujo", inseguro ou fora do padrão, o commit é rejeitado automaticamente.

- **Desafio Técnico (Python 3.13 & Arch Linux):**
    - **O Erro:** O hook do `ansible-lint` falhava ao criar o ambiente virtual. O erro `RuntimeError: failed to find interpreter` ocorria devido à versão *bleeding edge* do Python 3.13 no Arch Linux e à incapacidade do `pip` isolado de encontrar dependências de coleções (como `community.docker`).
    - **Solução:** Ajuste fino no arquivo de configuração para:
        1. Usar o metapacote `ansible` (Bateria inclusa) em vez de `ansible-core` nas `additional_dependencies`, garantindo que módulos comunitários sejam reconhecidos.
        2. Forçar `language_version: python3` para usar o interpretador estável do sistema.
    - **Erro Docker:** O hook padrão do `shellcheck` tentava rodar via Docker (ausente no notebook). Substituído pelo repo `shellcheck-py` que roda binário nativo.

- **Faxina (YAML Truthy):**
    - O linter detectou **72 violações** da regra `yaml[truthy]`.
    - **Contexto:** O Ansible historicamente aceitava `yes/no` para booleanos, mas o padrão YAML 1.2 estrito exige `true/false`.
    - **Ação:** Executada refatoração em massa via `sed` para converter `yes` -> `true` e `no` -> `false` em todos os playbooks e configurações, eliminando dívida técnica.

- **Segurança Ativa (Gitleaks):**
    - Integrado o Gitleaks no pipeline. Agora é matematicamente impossível commitar uma chave privada RSA ou um Token de API padrão sem usar uma flag de força bruta (`--no-verify`).

- **Documentação:** Criado documento técnico `docs/architecture/development-standards.md` detalhando a configuração do pipeline.
## 2026-02-23
**Status:** ✅ Sucesso (Deploy Seguro & Mudança de Cultura)

**Foco:** Implementação do Tududi e Adoção de Fluxo de Trabalho Profissional (Git Flow).

- **Evolução do GitOps (Feature Branches):**
    - **A Decisão:** Abandonei a prática amadora de "commit direto na main" ou mensagens de "bugfix".
    - **O Novo Padrão:**
        1.  Criar branch isolada: `git checkout -b feat/nome-do-recurso`.
        2.  Desenvolver e testar localmente.
        3.  Validar com Ansible no ambiente real.
        4.  Merge para `main` apenas quando estável ("Green Build").
    - **Resultado:** O histórico da `main` agora reflete apenas entregas de valor consolidadas, sem o ruído de tentativas e erros.

- **Serviço Novo: Tududi (Task Manager):**
    - **Objetivo:** Substituir o uso do "WhatsApp" para anotações e também ter um calendário com prazos integrado.
    - **Arquitetura:**
        - Container leve (`chrisvel/tududi`) com backend SQLite persistido no DockerHost.
        - **Segurança em Profundidade:** Dupla camada de autenticação.
            1.  **Borda (Traefik):** Middleware `authentik@docker` bloqueia qualquer acesso não autorizado antes mesmo de chegar na aplicação.
            2.  **Aplicação:** Login nativo do Tududi gerenciado por variáveis de ambiente injetadas.
    - **Automação (Ansible):**
        - Segredos (`Email`, `Password`, `Session Secret`) não existem em arquivos estáticos no Git. São solicitados via `vars_prompt` na hora do deploy e gravados em um `.env` com permissão `0600` no servidor.
    - **Prevenção de Falhas:** Aplicada a mesma lógica de correção de permissões (`chown 1000:1000`) nas pastas de dados antes do start do container, vacinando contra o erro que ocorreu no Syncthing.

## 2026-02-19
**Status:** ✅ Sucesso

**Foco:** Otimização de Memória e Fechamento do Perímetro da VM OrangeShadow.

- **System Tuning e Mitigação de OOM:**
    - Criado arquivo de Swap de 2GB no disco de boot (`local-zfs`) como contingência contra o OOM Killer do Linux durante picos de I/O de banco de dados.
    - Aplicado `vm.swappiness=10` via `sysctl` para garantir que o kernel esgote a RAM física antes de recorrer à paginação.
- **Micro-Segmentação (Zero Trust):**
    - UFW ativado na VM com *Default Deny*.
    - Liberadas portas estritas: 22 (SSH) e 9100 (Node Exporter, filtrado exclusivamente para o IP do DockerHost `10.10.30.10`). As portas P2P (8333, 18080) não foram abertas, isolando o roteamento externo para a rede Tor.
- **Planejamento de Cgroups e RAM:**
    - Documentada a estratégia de RAM para as fases de IBD. A VM operará com 16GB tanto para o IBD do BTC quanto do XMR (feitos sequencialmente), otimizando a indexação do LevelDB e LMDB.
    - Limites teóricos para a Fase de Produção (8GB RAM) recalibrados para garantir 1GB de margem real de segurança para o Sistema e tráfego Onion.
- **Wait Condition (Status Final):** A VM agora é um "bunker" selado. Nenhuma modificação estrutural será feita até a chegada do novo Nobreak para iniciar a operação de fato.

## 2026-02-18
**Status:** ✅ Sucesso

**Foco:** Implementação da Infraestrutura de Soberania Financeira (VM OrangeShadow).

- **Provisionamento da VM (OrangeShadow - ID 107):**
    - Criada VM Debian 13 Minimal na VLAN 30 (`10.10.30.20`).
    - **Disk Passthrough:** SSD Samsung 870 EVO (2TB) entregue fisicamente à VM para performance nativa de I/O.
    - **Particionamento Manual:** Configurei manualmente o disco de boot (32GB) com tabela GPT/EFI, preservando o SSD de 2TB intacto durante a instalação do OS.
    - **Formatação:** SSD de 2TB formatado em `ext4` com flag `-m 0` (recuperando ~100GB de espaço reservado) e montado em `/opt/blockchain`.

- **Automação e Hardening (Ansible):**
    - Atualizei `hosts.ini` incluindo o grupo `[orangeshadow]`.
    - Adaptei `hardening_debian.yml` para incluir a nova VM (usuário `sudo`, fail2ban, SSH keys...).
    - **Troubleshooting SSH:** Resolvi conflitos de *Host Key Verification* causados pela reciclagem de IPs e ausência de DNS inicial (fixado temporariamente com `echo nameserver...`).

- **Privacidade e Backup:**
    - **Tor:** Instalado e configurado como serviço de sistema para garantir anonimato futuro do Node.
    - **Backup:** Implementei lógica customizada no `setup_backup.yml` para o Restic. O script ignora a blockchain (TB de dados) e foca apenas em `wallet.dat` e arquivos de configuração, salvando em um repositório B2 dedicado (`/orangeshadow`).

- **Observabilidade:**
    - Node Exporter instalado via Ansible.
    - Atualizado `prometheus.yml` no DockerHost para raspar métricas da nova VM.
    - Dashboard validado no Grafana.

- **Wait Condition:** A VM está pronta, endurecida e operante, porém os serviços `bitcoind` e `monerod` **não foram instalados**. Aguardando chegada de novo Nobreak para evitar corrupção de banco de dados durante o IBD (Initial Block Download).

## 2026-02-16
**Status:** ⚠️ Revertido (Rollback de Funcionalidade)

**Foco:** Tentativa de implementação de Gerenciador de Arquivos Web e Endurecimento do Syncthing.

- **Experimento Falho: File Browser (Web Drive):**
    - **Objetivo:** Criar uma interface web estilo "Google Drive" (`files.home`) para gerenciar, deletar e mover arquivos dentro do volume do Syncthing, com SSO via Authentik.
    - **Implementação:**
        - Deploy via Docker Compose mapeando `/mnt/syncthing` como raiz.
        - Configuração de Proxy Auth (SSO) para ler o header `X-Authentik-Username`.
    - **O Problema:**
        - Apesar do container de debug `whoami` confirmar que o Authentik e Traefik estavam injetando os headers corretamente (`X-Authentik-Username: akadmin`), a aplicação File Browser ignorava consistentemente a instrução, exibindo a tela de login ou retornando "Wrong credentials".
        - Tentativas de forçar configuração via CLI (`config set`), variáveis de ambiente (`FB_AUTH_METHOD=proxy`) e recriação do banco de dados (`filebrowser.db`) não surtiram efeito.
    - **Decisão:** O esforço de troubleshooting excedeu o valor da funcionalidade. Stack removida completamente para evitar "zumbis" no servidor.

- **Reversão de Topologia Syncthing (Security First):**
    - Durante os testes do File Browser, a topologia foi alterada para *Send & Receive* (Bidirecional) para permitir deleção remota.
    - **Ação:** Com a remoção do gerenciador web, reverti a topologia para o modelo de **Segurança Máxima**:
        - **Servidor:** *Receive Only* (Apenas recebe dados, nunca propaga deleções para os clientes).
        - **Clientes (Arch/M55):** *Send Only* (São a fonte da verdade).
    - **Versionamento:** Mantido *Staggered File Versioning* no servidor como rede de segurança final contra erros humanos ou ransoms nos clientes.
## 2026-02-15
**Status:** ✅ Sucesso (CrowdSec Resurrection, Actual Budget Implementation and Syncthing Implementation)

**Foco:** Resolução definitiva do erro "Network Unreachable" no CrowdSec, além da implemtação do Actual Budget e do Syncthing

- **O Incidente (Zombie Container):**
    - **Sintoma:** O container `crowdsec` entrava em *Crash Loop* logo após iniciar, falhando ao tentar resolver DNS (`dial udp 10.10.30.5:53: connect: network is unreachable`) ou conectar à API central.
    - **Diagnóstico:** Estado de rede inconsistente no Docker Daemon. O container existia e rodava, mas sua interface de rede virtual estava "órfã" ou desconectada da bridge `proxy`, impedindo o roteamento de saída. Simplesmente reiniciar (`restart`) não resolvia pois reutilizava o container defeituoso.
- **A Solução:**
    - Executado `docker compose up -d --force-recreate` na pasta `/opt/security`.
    - **Efeito:** O comando forçou a destruição do container antigo e a criação de um novo do zero, reatribuindo corretamente as interfaces de rede e rotas.
- **Validação:**
    - Hub atualizado com sucesso (`community-blocklist: added 2400 entries`).
    - Bouncer do OPNsense (`10.10.30.1`) reconectado imediatamente: logs mostram `GET /v1/decisions/stream ... HTTP 200`.
- **Serviço Novo: Actual Budget**
    - **Objetivo:** Controle financeiro soberano (Substituição de planilhas/PicPay mental).
    - **Decisão de Arquitetura:** Optei pela imagem oficial `ghcr.io/actualbudget/actual-server`. Diferente dos outros serviços, este **não usa o Authentik** como barreira de entrada.
    - **Motivo:** O App mobile do Actual Budget não suporta fluxos de autenticação complexos (OIDC/ForwardAuth).
    - **Mitigação:** A segurança depende da senha forte do servidor e, crucialmente, da **End-to-End Encryption** ativada nas configurações do Actual.
- **Serviço Novo: Syncthing (Central Data Hub)**
    - **Objetivo:** Centralizar arquivos do Notebook (Arch) e Celular (M55) para backup e futura ingestão no Immich, sem depender de nuvem pública.
    - **Expansão de Hardware (Storage):**
        - Adicionado disco virtual de **100GB** ao DockerHost no Proxmox.
        - **Prevenção de Desastre:** Para evitar o incidente de "Boot Loop" do dia 11/02, o disco foi montado via **UUID** (`/etc/fstab`) em vez do device path (`/dev/sdb`), garantindo estabilidade mesmo se a ordem dos cabos virtuais mudar.
        - **Mount Point:** `/mnt/syncthing`. Formatado em `ext4`.
        - **Flag de Segurança:** Adicionado `nofail` no fstab. Se este disco corromper, o servidor ainda bootará os serviços críticos (DNS/Auth).
    - **Incidente de Deploy (Permission Crash Loop):**
        - **Sintoma:** O container entrava em *Crash Loop* imediato. Logs mostravam `chmod /var/syncthing/config: operation not permitted`.
        - **Causa Raiz:** O Docker Engine (rodando como root) criou a pasta de bind mount `config/` automaticamente com permissão `root:root`. O processo interno do Syncthing (UID 1000) não conseguia escrever seus certificados.
        - **Solução:** Atualizado o playbook `services.yml` no Ansible. Inserida uma task `file` explícita para garantir `owner: 1000` e `group: 1000` na pasta de configuração *antes* de subir o container.
    - **Arquitetura de Pastas (Split-Storage):**
        - **Configuração:** Mantida no disco de boot (`/opt/services/syncthing/config`) para ser incluída no Backup do Restic.
        - **Dados Brutos:** Direcionados para o disco de 100GB (`/mnt/syncthing`), mapeado internamente como `/var/syncthing/data`. **Excluído** do backup do Restic para economizar custos de B2.
        - **Estrutura Lógica:**
            - `/mnt/syncthing/M55/`
            - `/mnt/syncthing/Arch/`
    - **Otimização de Performance & Segurança:**
        - **No Servidor (Docker):**
            - Desativado `NAT/UPnP` (Inútil atrás de CGNAT/Docker Network).
            - Ativado `Ignore Permissions` (Crucial para evitar conflitos entre Android/Linux/Docker permissions).
            - Interface Web protegida em profundidade: Middleware Authentik + Senha forte interna.

## 2026-02-13
**Status:** ✅ Sucesso (Fragmentação do Manage_Stacks.yml)

**Foco:** Tornar o uso do Ansible mais prático e menos trabalhoso.

- **Ação:** O playbook `manage_stacks.yml` foi dividido em arquivos menores.
- **Motivo:** Evitar rodar o playbook completo toda vez que se faz uma alteração e facilitar a gestão de chaves, tokens e senhas.
- **Resultado:** Mais agilidade na manutenção e menor risco de erro ao manipular variáveis sensíveis.

## 2026-02-12
**Status:** ✅ Sucesso (Decomposição de Stack Desnecessária)

**Foco:** Remoção da Stack de Mídia e Simplificação do Server.

- **Decisão (O Carro na Garagem):**
    - Após refletir sobre o uso real, decidi descontinuar toda a stack de mídia.
    - **Motivo:** Manter essa infraestrutura complexa sem uso frequente é um desperdício de recursos e tempo de manutenção. Como quase não vejo filmes/séries (prefiro resumos ou baixar pontualmente no Arch), manter isso seria como "ter um carro que só fica na garagem para nada".
- **Resultados dos Testes:**
    - A stack chegou a funcionar: o qBittorrent via VPN (Gluetun) e o Jellyfin estavam operacionais e acessíveis pelo Arch Linux.
    - **Falhas:** Dificuldade persistente na conexão com a TV (VLAN IOT) e na automação de legendas (Bazarr).
- **Ações Realizadas:**
    - Remoção de todos os containers da Stack Arr (Radarr, Sonarr, Prowlarr, FlareSolverr, Bazarr, Jellyfin, Jellyseerr, Gluetun e qBittorrent).
    - Desmontagem e remoção do disco virtual de 500GB dedicado a mídias no Proxmox.
    - Limpeza das regras de firewall específicas para a TV no OPNsense.
## 2026-02-11
**Status:** ✅ Sucesso (Disaster Recovery & Stabilization)

**Foco:** Recuperação de Falha Crítica de Boot e Estabilização de Storage.

- **O Incidente (Boot Loop):**
    - Após desligar o servidor ontem, ao ligá-lo hoje, o DockerHost não respondeu ao Ping nem conectou à VPN.
    - **Sintoma no Console:** O sistema caiu em *Emergency Mode* (Shell de root bloqueado).
    - **Logs de Erro:**
        - `[FAILED] Failed to mount mnt-media.mount /mnt/media.`
        - `[DEPEND] Dependency failed for local-fs.target.`
    - **Causa Raiz:** Mudança na topologia de dispositivos SCSI.
        - Ontem, o disco de 500GB era `/dev/sda` e o Boot era `/dev/sdb`.
        - Hoje, o Proxmox inverteu: Boot virou `/dev/sda`.
        - O `/etc/fstab` tentou montar o disco de boot (sda) na pasta `/mnt/media` com sistema de arquivos incorreto, travando o boot.

- **Operação de Resgate (GRUB Hack):**
    - Como o acesso SSH estava morto e o root bloqueado, utilizei a edição de parâmetros de Kernel no GRUB.
    - **Ação:** Adicionado `init=/bin/bash` na linha de boot do Linux (`Ctrl+x` para bootar).
    - **Acesso:** Obtido shell de root com sistema de arquivos *Read-Only*.

- **O Desafio do Teclado (VNC Bug):**
    - Ao tentar editar o `fstab` com `nano`, descobri que as teclas `Ctrl` e `Shift` não funcionavam no console NoVNC do Proxmox, impedindo de salvar o arquivo ou digitar `#` para comentar a linha falha.
    - **Solução (Stream Editor):** Reiniciei o processo de resgate e utilizei o `sed` para deletar a linha problemática sem precisar de editor interativo:
        1. `mount -o remount,rw /` (Tornar disco gravável).
        2. `sed -i '/mnt\/media/d' /etc/fstab` (Deletar qualquer linha contendo o mount point).
        3. `echo b > /proc/sysrq-trigger` (O ">" também não funcionava, então fiz via GUI do Proxmox mesmo (Stop e Start)).

- **Correção Definitiva (Ansible):**
    - Com o servidor online (sem o disco de mídia), corrigi o playbook `setup_storage.yml`.
    - **Mudança:** Substituído o alvo fixo `src: /dev/sda` por `src: LABEL=media_disk`.
    - **Resultado:** O Ansible remontou o disco corretamente. O uso de LABEL garante que o boot funcione independente da ordem que o Proxmox apresente os cabos virtuais.

## 2026-02-10
**Status:** ✅ Sucesso (Media Automation Stack)

**Foco:** Implementação da Stack Arr (Servidor de Mídia) com VPN Isolada.

- **Infraestrutura de Storage:**
    - Adicionado disco virtual de 500GB (`Raw disk image`) ao DockerHost.
    - Formatado como `ext4` (sem reserva de root `-m 0`) via Ansible.
    - **Estrutura de Pastas:** Criada hierarquia unificada `/mnt/media/data/{torrents,media}` para permitir **Hardlinks Atômicos** (Atomic Moves). Isso impede que o download e a cópia final ocupem o dobro do espaço em disco.

- **VPN & Privacidade (Gluetun):**
    - Implementado container `gluetun` conectado à ProtonVPN (WireGuard).
    - **Funcionalidade:** O container `qbittorrent` não tem rede própria; ele usa `network_mode: service:gluetun`. Se a VPN cair, o torrent para imediatamente (Kill Switch nativo).
    - **Port Forwarding:** Habilitado NAT-PMP para garantir conectividade com peers.

- **Troubleshooting de Deploy:**
    - **Conflito de Portas:** O container `crowdsec` falhou ao iniciar.
        - *Causa:* Ambos CrowdSec e qBittorrent tentaram usar a porta `8080` do host.
        - *Correção:* Mapeada a WebUI do qBittorrent para a porta `8085` no `docker-compose.yml`.
    - **Erro de Permissão (PGID):** Ajustado `PGID=989` (Grupo Docker) nos containers para garantir acesso de escrita no disco montado.

- **Incidente de Roteamento (Traefik 504):**
    - **Sintoma:** Serviços como Radarr e Sonarr retornavam *Gateway Timeout* intermitente.
    - **Diagnóstico:** Os containers estavam conectados a duas redes (`media_net` interna e `proxy` externa). O Traefik estava resolvendo o IP da rede interna (172.18.x.x), a qual ele não tem acesso.
    - **Solução:** Adicionada a label `traefik.docker.network=proxy` em todos os serviços. Isso força o Traefik a utilizar apenas o IP da rede compartilhada de ingress.

- **Integração Authentik:**
    - Criados *Proxy Providers* manuais para cada serviço (`*.home`), garantindo camada de autenticação única antes de acessar as aplicações.
    - Adicionado middleware `authentik` nas labels do Traefik para forçar o login.
## 2026-02-08
**Status:** ✅ Sucesso (Refactoring & Troubleshooting)

**Foco:** Organização Semântica de Diretórios e Correção de Conectividade do CrowdSec.

- **Reestruturação de Diretórios:**
    - **Problema:** A pasta `configuration/dockerhost` estava se tornando um "lixão" de pastas misturadas, e o servidor refletia essa desorganização na raiz de `/opt/`.
    - **Ação:** Implementada segregação funcional:
        - `/opt/services`: Para infraestrutura de aplicação (Traefik, Vaultwarden, Nostr, Tailscale).
        - `/opt/auth`: Isolamento para o stack de Identidade (Authentik).
        - `/opt/monitoring` e `/opt/security`: Mantidos como estavam.
    - **Automação:** Refatorado `manage_stacks.yml` para sincronizar estas pastas recursivamente, com cuidado crítico de adicionar `rsync_opts: "--exclude=data/"` para não sobrescrever bancos de dados em produção com pastas vazias do Git.
    - **Resultado:** O comando `tree` no servidor agora reflete uma arquitetura limpa e escalável.

- **Incidente CrowdSec:**
    - **Sintoma:** O container `crowdsec` entrou em *Crash Loop* com erro `dial udp 10.10.30.5:53: connect: network is unreachable`.
    - **Diagnóstico Inicial:** Suspeita de conflito com as regras de `iptables` inseridas ontem pelo `tailscale-nat.service` (VPN).
    - **Investigação Forense:**
        - O comando `docker network inspect proxy` revelou que o container `crowdsec` **não estava listado** na rede, apesar de estar definido no `docker-compose.yml`. Ele estava "órfão" em execução, sem gateway.
    - **Causa Raiz:** Inconsistência de estado do Docker Daemon. Após alterações manuais de iptables (pelo serviço de VPN) e restarts de serviço, o Docker perdeu a referência de rede do container antigo. Reiniciar o serviço Docker não foi suficiente para corrigir o vínculo.
    - **Solução Definitiva:** Executado `docker compose up -d --force-recreate` na pasta `/opt/security`. Isso forçou a destruição do container "zumbi" e a criação de um novo, injetando corretamente as interfaces de rede e DNS.
    - **Validação:** Logs mostram conexão imediata com a LAPI local e o Bouncer do OPNsense (`HTTP 200`).

- **Dead Man's Switch ("Quem vigia o vigia?"):**
    - **Cenário de Risco:** Identificado que uma falha catastrófica de hardware ou energia no DockerHost mataria também o sistema de alertas (Alertmanager/Ntfy), resultando em silêncio total (falso positivo de normalidade).
    - **Solução:** Implementação de monitoramento passivo externo (Healthchecks.io).
    - **Implementação Técnica:**
        - Adicionado container `heartbeat` no stack de monitoramento executando um loop infinito de `curl` a cada 300 segundos.
        - **Segurança de Código:** O UUID da URL não foi hardcodado no Git. Atualizado o `manage_stacks.yml` para solicitar o UUID no prompt e injetar no `.env` do servidor como `HEALTHCHECKS_URL`.
    - **Troubleshooting:**
        - Enfrentei erro de validação no Docker Compose (`additional properties 'heartbeat' not allowed`).
        - *Causa:* Erro de indentação (espaços extras) que colocou o serviço `heartbeat` dentro da definição do serviço `ntfy`.
        - *Correção:* Ajuste de indentação YAML.
    - **Validação:** Desligamento do servidor. O serviço externo detectou a ausência do ping e disparou o alerta por e-mail após o tempo de tolerância (Grace Time) de 2 minutos.
## 2026-02-02
**Status:** ✅ Sucesso (Observabilidade Total & Integridade de Dados)

**Foco:** Blindagem do Backup do Authentik, Métricas de VPN e Implementação de SIEM (Logs de Auditoria).

- **Backup "À Prova de Balas" (Integridade):**
    - **Risco Identificado:** O backup via Restic copiava os arquivos do PostgreSQL (`/var/lib/postgresql/data`) com o banco rodando, o que garantiria um restore corrompido.
    - **Solução:** Alterado o script de backup no Ansible para executar um `pg_dump` (Dump Lógico) para um arquivo `.sql` antes da execução do Restic.
    - **Resultado:** Agora tem um arquivo estático e consistente do banco de dados do Authentik salvo diariamente.

- **Observabilidade da VPN (Tailscale):**
    - **Desafio:** As métricas nativas não apareciam. O comando `curl` na porta 9002 falhava.
    - **Diagnóstico:** A variável `TS_EXTRA_ARGS` usada para passar flags no `docker-compose` aplica-se apenas ao comando de login (`tailscale up`), não ao daemon de fundo.
    - **Correção:** Migrado para a variável `TS_TAILSCALED_EXTRA_ARGS` e utilizada a flag de debug (`--debug=0.0.0.0:9002`), já que a flag dedicada de métricas foi removida/renomeada nas versões recentes.
    - **Resultado:** Prometheus agora coleta uso de memória e tráfego de pacotes do túnel VPN.

- **SIEM Leve (Loki & Alloy):**
    - **Objetivo:** Responder à pergunta "Quem está acessando meu servidor e o que estão executando?".
    - **Incidente 1 (O Arquivo Fantasma):**
        - *Sintoma:* O container do Alloy falhava ao iniciar com erro de "is a directory".
        - *Causa:* O arquivo `/var/log/auth.log` não existia no Host. O Docker, ao tentar montar o volume, criou uma pasta com esse nome.
        - *Solução:* Removida a pasta manualmente e criado o arquivo via `touch`. Adicionada tarefa no Ansible para garantir a existência do arquivo *antes* do deploy do container.
    - **Incidente 2 (Rejeição Temporal):**
        - *Sintoma:* Logs não apareciam no Grafana. Logs do Alloy mostravam erro 400 do Loki.
        - *Causa:* O Alloy tentava ler o histórico do `journald` desde o início (dias atrás). O Loki rejeita logs fora da janela de ingestão configurada.
        - *Solução:* Configurado `max_age = "1h"` no `config.alloy` para focar apenas no presente.
    - **Vitória:** Logs de execução de `sudo` (Auditoria de Privilégio) e conexões SSH agora são visíveis e consultáveis no Grafana.
        - Para o futuro: configurar regras no Loki/Alertmanager para notificar via Ntfy sobre execução de `sudo` e falhas repetidas de SSH.
## 2026-02-01
**Status:** ✅ Sucesso (Remote Access & VPN Architecture)

**Foco:** Implementação de VPN Primária (Tailscale Subnet Router) no DockerHost e Automação de AuthKey.

- **VPN Primária (DockerHost):**
    - **Objetivo:** Permitir acesso total à rede de serviços (`10.10.0.0/16`) de fora de casa.
    - **Arquitetura de Roteamento:**
        - Habilitado `IP Forwarding` no Kernel via Ansible.
        - **Desafio do Retorno (Return Path):** O firewall OPNsense descartava pacotes voltando para a rede VPN (`100.x.y.z`) pois desconhecia a rota.
        - **Solução (NAT):** Implementado **Masquerading** (`iptables -t nat ...`) na interface do DockerHost. O tráfego da VPN agora "finge" ser o próprio DockerHost, garantindo que as respostas voltem corretamente.
        - **Bypass do Docker:** Adicionadas regras na chain `FORWARD` para permitir que o tráfego da interface `tailscale0` atravesse o bloqueio padrão do Docker.
    - **Persistência:** Criado serviço `tailscale-nat.service` (Systemd) para reaplicar as regras de firewall no boot automaticamente.

- **Automação e Autenticação:**
    - Migrado para **AuthKey Reutilizável** injetada via arquivo `.env` protegido (`0600`).
    - Diretório `state/` excluído da sincronização do Ansible (`rsync_opts`) para evitar perda de identidade da máquina a cada deploy.

- **Acesso ao Vault (Jump Server):**
    - O acesso SSH direto via VPN ao Vault (`10.10.40.10`) era bloqueado pelo UFW (Allow apenas Trusted/Mgmt).
    - **Ajuste:** Liberado SSH vindo do IP do DockerHost (`10.10.30.10`).
    - **Fluxo:** VPN -> SSH DockerHost -> SSH Vault (Jump Host Pattern).

- **DNS (Split Horizon):**
    - Configurado **Split DNS** no painel Tailscale apontando `*.home` para o AdGuard (`10.10.30.5`).
    - Isso permite acessar serviços internos (ex: `https://vaultwarden.home`) via VPN sem expor o DNS para o resto da internet.
## 2026-01-31
**Status:** ✅ Sucesso (Sovereignty & Privacy)

**Foco:** Implementação de Relay Nostr Soberano, Tor Hidden Service e Auditoria de Clientes.

- **Arquitetura Soberana (Nostr):**
    - **Stack:** Implementado `scsibug/nostr-rs-relay` (Rust) com backend SQLite.
    - **Segurança:** Configurada **Whitelist** de PubKey. O relay é público para leitura, mas restrito para escrita (apenas minha chave privada pode postar), atuando como um "Cofre Digital" pessoal.
    - **Acesso Híbrido:**
        1.  **Local (LAN):** Via `wss://nostr.home` (Alta performance/baixa latência).
        2.  **Mundial (Tor):** Via Hidden Service `.onion` (Anonimato e resistência à censura).

- **Permissões e CRLF (Tor):**
    - **Incidente 1 (Permissões):** O Tor entrava em crash loop (`Permissions on directory ... are too permissive`).
        - *Causa:* O Ansible sincronizava a pasta `tor-keys` com permissões do usuário `fajre` (1000), mas o processo Tor rodava como `root`.
        - *Correção:* Ajustada task no Ansible para forçar `owner: root` e `mode: 0700` na pasta de chaves.
    - **Incidente 2 (Sintaxe/CRLF):** O Tor falhava com `Unparseable address`.
        - *Causa:* O arquivo `torrc` criado no editor local continha quebras de linha ou caracteres ocultos incompatíveis.
        - *Correção:* Recriação do arquivo diretamente no servidor via `printf` limpo e posterior sincronização Git.

- **Roteamento e "Split-Brain" (Traefik):**
    - **Sintoma:** Acesso local (`nostr.home`) retornava `504 Gateway Timeout`, mas `wget` interno funcionava.
    - **Causa:** O container estava em duas redes (`tor-net` e `proxy`). O Traefik tentava rotear pelo IP da rede Tor (invisível para ele).
    - **Correção:** Adicionada label explícita `traefik.docker.network=proxy` no `docker-compose.yml` para forçar a rota correta e removido vários middlewares desnecessários e bloquedores.

- **Auditoria de Clientes (Client-Side vs Cache):**
    - **Fenômeno:** Posts feitos via celular (Amethyst) não apareciam no PC (Primal Web), apesar de constarem no banco de dados (validado via ferramenta CLI `nak`).
    - **Descoberta:** O **Primal** utiliza um cache centralizado proprietário e não indexa relays privados/locais/Tor.
    - **Solução:** Migração no Desktop para o **Coracle** (Web Client que realiza conexões diretas via Socket no navegador), permitindo visualização real dos dados soberanos.

- **Amethyst & Tor Nativo:**
    - Validado que o cliente Android **Amethyst** possui suporte nativo a endereços `.onion` (via `kmp-tor` embutido).
    - *Nota:* O certificado SSL local (`mkcert`) é rejeitado pelo Android, tornando o acesso via `.onion` a via preferencial no mobile.

## 2026-01-30
**Status:** ✅ Sucesso (Maintenance & Stability)

**Foco:** Revisão de Repositório e Estabilidade do CrowdSec.

- **Repo Hygiene:**
    - Revisão estrutural de todas as documentações para garantir conformidade com o estado atual da infraestrutura.

- **CrowdSec Stability Fix (DNS Loop):**
    - **Sintoma:** O container `crowdsec` entrava em *Crash Loop* (restart a cada 15s) e o Grafana exibia "No Data".
    - **Erro no Log:** `dial udp 1.1.1.1:53: connect: network is unreachable`.
    - **Causa Raiz:** A política de Firewall "Default Deny" na VLAN SERVER (30) bloqueia consultas DNS diretas para a internet (UDP/53). O container estava configurado com um outro DNS externo (`1.1.1.1`) no `docker-compose.yml`.
    - **Correção:** Removio esse DNS e deixado somente o DNS do container para o AdGuard Home interno (`10.10.30.5`), que possui permissão de saída explícita no firewall.
    - **Resultado:** O container estabilizou, baixou as regras do Hub e o Bouncer no OPNsense conectou com sucesso (HTTP 200).

## 2026-01-29
**Status:** ✅ Sucesso (Acesso Out-of-Band & Disaster Recovery)

**Foco:** Implementação da VPN (Tailscale) no RPi.

- **VPN de Emergência (Raspberry Pi):**
    - **Objetivo:** Criar um túnel direto para desbloquear a criptografia LUKS (via Dropbear) do servidor fora de casa.
    - **Implementação:**
        - Raspberry Pi configurado como *Subnet Router* (`192.168.0.0/24`) via Ansible (Playbook `hardening_rpi.yml`).
        - **Segurança (ACLs):** Configurado no painel da Tailscale para bloqueio total (Default Deny).
        - **Regra:** A tag `tag:rpi` permite tráfego de saída **exclusivamente** para o IP `192.168.0.200` na porta `2222` (Dropbear). Nenhum acesso lateral à rede doméstica é permitido. Somente usuários com minha conta podem acessar.

- **Fixação de IP de Boot (Proxmox):**
    - **Problema:** O Dropbear no initramfs dependia de DHCP. Antes eu utilizava `nmap -p 2222 --open 192.168.0.0/24` para saber qual era o IP do Dropbear na rede.
    - **Ação Manual (Bootstrap):** Editado `/etc/initramfs-tools/initramfs.conf` no Host.
    - **Configuração:** `IP=192.168.0.200::192.168.0.1:255.255.255.0:homelab:enp4s0:off`.
    - **Interface:** Confirmado o uso de `enp4s0` (Nome de Kernel) em vez de `nic0` (Nome Systemd).
    - **Resultado:** IP estático, reduzindo perda de tempo procurando o IP.

- **Configuração de Clientes:**
    - **Android (Termux):** Gerado par de chaves `ssh-ed25519` e adicionado ao `/etc/dropbear-initramfs/authorized_keys` via Proxmox desbloqueado.
    - **Arch:** Instalado cliente Tailscale e validado acesso com `--accept-routes`.

- **Incidente de DNS (Arch Linux):**
    - **Sintoma:** Após desconectar a VPN (`tailscale down`), a internet no notebook parou de funcionar (`ping google.com` falhava, mas `1.1.1.1` funcionava).
    - **Causa:** O `NetworkManager` não reverteu corretamente as configurações de DNS (MagicDNS) ao sair do túnel.
    - **Solução:** `sudo systemctl restart NetworkManager`. Conectividade restaurada imediatamente.

- **Teste de Fogo (Disaster Recovery):**
    - Simulado corte de Wi-Fi e acesso via 5G.
    - Conexão SSH no Dropbear realizada com sucesso através do túnel. Desbloqueio de disco validado.

## 2026-01-28
**Status:** ✅ Sucesso (Com alta complexidade resolvida)

**Foco:** Observabilidade Ativa (Alertas) e Monitoramento de Virtualização (Proxmox/LXC).

- **CrowdSec (Correção Crítica):**
    - **Sintoma:** Container CrowdSec em loop de erro DNS (`connection refused` para `127.0.0.53`).
    - **Causa:** O container herdava o `/etc/resolv.conf` do Host (systemd-resolved), mas não tinha acesso ao loopback do host.
    - **Solução:** Forçado DNS explícito (`10.10.30.5`, `1.1.1.1`) no `docker-compose.yml`. Comunicação com a CAPI e Bouncer restabelecida.

- **Alertmanager & Ntfy (Observabilidade Ativa):**
    - Implementado `alert.rules.yml` no Prometheus (Regras: InstanceDown, DiskSpace, HighRAM, HighCPU).
    - Configurado Alertmanager para enviar notificações JSON via Webhook para o Ntfy local (`deny-all` com Token).
    - **Troubleshooting:**
        - Erro de permissão (`0600`) no arquivo de config gerado pelo Ansible impedia leitura pelo usuário `nobody` do container. Ajustado para `0644`.
        - Erro de volume: O arquivo de regras não estava mapeado no `docker-compose`. Corrigido.
    - **Teste:** Exeutado `systemctl stop prometheus-node-exporter`, após cerca de 4 minutos foi recebido o alerta no ntfy.

- **Expansão de Agentes (Node Exporter):**
    - Instalado `prometheus-node-exporter` nativo no Host Físico (Proxmox) e na VM Vault.
    - **Network:** Ajustada regra UFW no Vault para permitir entrada na porta 9100 apenas vinda do DockerHost (`10.10.30.10`).

- **Proxmox VE Exporter (O Desafio do Dia):**
    - **Objetivo:** Monitorar métricas individuais de LXCs e VMs (que o Node Exporter não vê).
    - **Incidente (Dependency Hell):** A imagem `prompve/prometheus-pve-exporter:latest` contém uma versão da biblioteca `proxmoxer` incompatível com os parâmetros `token` ou `api_token` do script de inicialização. Causou *crash loop*.
    - **Workaround:** Revertido método de autenticação para `user/password` no `pve.yml`.
    - **Alertas:** Criadas regras inteligentes usando `rate()` para CPU de VMs, evitando falsos positivos.

- **Grafana as Code:**
    - Dashboard ID 10347 (Proxmox VE) importado, higienizado (remoção de IDs fixos) e salvo como código em `provisioning/dashboards/proxmox-ve.json` para persistência via Ansible.

## 2026-01-27
**Status:** ❌ Falha (Experimento Abortado)

**Foco:** Implementação de IA Local (RAG Assistant) e Benchmark de Performance CPU-Only.

- **Objetivo:** Criar um assistente "Jarvis" soberano (Ollama + Open WebUI) rodando no hardware existente (i5-12400 + 64GB RAM) capaz de ler a documentação do Homelab (RAG).
- **E o Clawdbot?** É uma ferramenta de agente autônomo. Ele executa coisas. Para ele ser útil, ele precisa de permissão de escrita e execução. No meu Homelab focado em segurança ("Default Deny"), instalar um agente que varre o sistema e tem acesso ao shell é pedir para ser hackeado ou sofrer um acidente catastrófico (ex: alucinação de IA deletando configs ou vazar dados). É "hype" de X, não infraestrutura séria. Talvez esperar o hype abaixar, ver o que a comunidade está achando e implementar com cuidados no futuro.

- **Infraestrutura Provisionada:**
    - Criado LXC `110 (AI-Node)` na VLAN 30 com 24GB de RAM dedicados e 4 vCores.
    - Automação via Ansible: Playbook `setup_ai_node.yml` implementado para deploy da stack Docker + Clonagem do Repositório para contexto.
    - **Correção de Runtime:** Necessário remover limites de `ulimit/memlock` do Docker Compose, pois containers LXC não permitem controle direto de memória do Kernel do Host.

- **Benchmark de Modelos (CPU Inference):**
    - **Teste 1: Cohere Command-R (35B):**
        - *Expectativa:* Alta capacidade de RAG e citações precisas.
        - *Realidade:* Inviável. O modelo de ~20GB saturou a banda de memória DDR4. Latência de resposta superior a 6 minutos.
    - **Teste 2: Llama 3.1 (8B Instruct):**
        - *Expectativa:* Modelo equilibrado padrão de mercado.
        - *Realidade:* Geração lenta (~3-5 tokens/s). A experiência de chat em tempo real foi frustrante e "travada".
    - **Teste 3: Llama 3.2 (3B):**
        - *Expectativa:* Modelo "Edge" otimizado para latência baixa.
        - *Realidade:* Melhor velocidade, mas ainda aquém da instantaneidade necessária para um assistente fluido. A inteligência reduzida também comprometeu a análise de documentos complexos.

- **Veredito Técnico:**
    - A inferência de LLMs modernos depende criticamente de largura de banda de memória (VRAM/RAM) e processamento paralelo massivo (Cores CUDA).
    - O Intel i5-12400 (mesmo com AVX2) não possui throughput suficiente para sustentar uma experiência de chat agradável sem GPU dedicada.

- **Ação de Contenção (Cleanup):**
    - **Infraestrutura:** Container LXC 110 destruído e recursos (24GB RAM) devolvidos ao Host.
    - **Código:** Revertidos commits de infraestrutura (`hosts.ini`, playbooks) para manter o repositório limpo de "código morto".
    - **Futuro:** Projeto suspenso até a aquisição de acelerador de hardware (GPU Nvidia ou NPU dedicada).
## 2026-01-25
**Status:** ✅ Sucesso (Security Incident Response & Hardening)

**Foco:** Resposta a Incidente de Vazamento de Credenciais, Refatoração do Vault e Observabilidade do CrowdSec.

- **CrowdSec Observability (Métricas & Alertas):**
    - **Prometheus:** Realizada "cirurgia" no `config.yaml` dentro do container para habilitar o módulo Prometheus e alterar o bind para `0.0.0.0`, permitindo coleta externa na porta `6060`.
    - **Ntfy Integration:**
        - Implementado template de notificação `http.yaml`.
        - **Fix de Template:** Simplificado o formato da mensagem para remover a variável `.Source.CN` (Country Name), que causava crash do plugin em testes manuais (IPs sem geolocalização).
        - **Fix de Rede:** Alterada a URL de notificação de `http://10.10.30.10` para `http://ntfy:80` (Rede interna Docker) para contornar problemas de *Hairpin NAT* e erros de certificado SSL autoassinado.
    - **Validação:** Testes de ataque simulado (`cscli decisions add`) geram alertas imediatos no celular.

- **Incidente de Segurança (Data Leak):**
    - **Evento:** Durante o push das configurações de notificação, identificou-se que o Token do Ntfy e os `ROLE_ID` do Vault (Authentik/Vaultwarden) foram commitados em texto plano no repositório público.
    - **Análise de Risco:** Exposição de credenciais de "Nome de Usuário" (RoleID) e Token de Push. Risco de spam de notificações e redução da entropia de segurança do Vault.
    - **Ação Imediata:** Revogação do Token Ntfy e desabilitação/habilitação do método AppRole no Vault, invalidando todos os IDs anteriores.

- **Refatoração Arquitetural (Vault AppRole):**
    - **Nova Estratégia:** Adotado o padrão "Gold Standard" para repositórios públicos.
        - Scripts de inicialização (`start-with-vault.sh`) transformados em arquivos "burros" que leem credenciais do disco.
        - Segredos (`ROLE_ID`, `SECRET_ID`) movidos para `/etc/vault/` com permissão `0600` (root only).
    - **Automação Ansible:**
        - Atualizado `manage_stacks.yml` para solicitar as novas credenciais via `vars_prompt` (RAM apenas) e gravá-las nos arquivos protegidos.
        - Templates `.j2` removidos do fluxo de cópia direta.
    - **Limpeza:** Removidos arquivos sensíveis do histórico Git e aplicados novos templates sanitizados.

- **Correção de Backup (Disaster Recovery):**
    - **Gap Identificado:** Os diretórios `/opt/security` (Dados do CrowdSec) e a nova estrutura `/etc/vault` (Credenciais de Boot) não estavam no backup diário.
    - **Fix:** Atualizado playbook `setup_backup.yml` para incluir estes caminhos.
    - **Validação:** Execução manual do Restic confirmou a inclusão dos arquivos `.secretid` e `.roleid` no snapshot criptografado.

- **Dashboard as Code (Grafana):**
    - **Implementação:** Baixado o JSON oficial do CrowdSec (ID 19010) para o repositório Git.
    - **Incidente de Provisionamento:** O dashboard carregava vazio ("Datasource not found").
    - **Diagnóstico:** O Grafana em modo *provisioning* não resolve o nome "Prometheus" automaticamente se o JSON esperar um Input variável.
    - **Correção Sênior:** Hardcoded o UID do Datasource (`dfa44v3b15a80b`) diretamente no JSON antes do commit, eliminando a dependência de inputs manuais.

- **Nobreak NHS Gamer Play (Incompatibilidade):**
    - **Tentativa:** Integração via NUT no Raspberry Pi (USB).
    - **Hardware ID:** `0925:1241` (NXP/Lakeview Virtual COM).
    - **Diagnóstico:** - Driver `nutdrv_qx`: Falha (Dispositivo não é HID compliant).
        - Driver `blazer_ser`: Falha (Protocolo proprietário/Short Reply na porta `/dev/ttyACM0`).
    - **Conclusão:** O modelo possui firmware travado/proprietário incompatível com o padrão open-source.
    - **Ação:** Devolução e encontrar um outro, que seja compatível.

- **Status Final:**
    - Infraestrutura recuperada e mais segura do que antes do incidente.
    - Serviços Authentik e Vaultwarden reiniciados e operando com as novas credenciais rotacionadas.
    - CrowdSec com uma boa observabilidade no Grafana.
    - Repositório Git limpo de segredos.
## 2026-01-24
**Status:** ⚠️ Sucesso Parcial (Perímetro OK, Camada 7 Parcial)

**Foco:** Carregamento do Nobreak NHS, Deploy do CrowdSec (LAPI + Bouncer) e Troubleshooting de Parsing de Camada 7.

- **Infraestrutura Elétrica (Nobreak NHS):**
    - **Hardware:** Adquirido Nobreak NHS Gamer Play 1000VA (Senoidal Pura).
    - **Protocolo de Ativação:** Iniciado ciclo de carga de 12 horas (sem carga conectada) para equalização das baterias internas (2x 7Ah).
    - **Dimensionamento:** Carga estimada de 160W (~26%), garantindo autonomia superior a 20 minutos.

- **Implementação CrowdSec (Defesa Ativa):**
    - **Arquitetura Cérebro-Músculo:** LAPI (Agente/Cérebro) centralizado no DockerHost e Bouncer (Músculo) no OPNsense.
    - **Segurança de Rede:** Porta 8080 do LAPI configurada com *Bind IP* exclusivo para o IP interno do DockerHost (`10.10.30.10`), isolando a API da rede externa.
    - **Resolução de Metadados:** Conexão do CrowdSec ao `socket-proxy` via `DOCKER_HOST` para identificação de nomes de containers nos logs.

- **Troubleshooting de Parsing (Authentik):**
    - **Desafio do Hub:** A coleção oficial para Authentik foi identificada como `firix/authentik`.
    - **YAML Hell (acquis.yaml):** - *Tentativa 1 (Falha):* Filtros dinâmicos via `evt.Parsed` falharam (aquisição ocorre antes do parsing).
        - *Tentativa 2 (Sucesso):* Implementado apontamento via **Hardcoded Container ID** no `acquis.yaml` para forçar o `type: authentik`.
        - **⚠️ Manutenção Crítica:** Caso o container do Authentik seja recriado (update), o ID em `acquis.yaml` deve ser atualizado para evitar cegueira do parser.
    - **Resultado Técnico Real:**
        - O parser `firix/authentik-logs` está ativo e recebendo eventos (`Hits > 0`).
        - **Parsed = 0** mesmo após falhas reais de login.
        - **Impacto:** Nenhuma decisão automática de banimento é gerada a partir de falhas de autenticação no Authentik.
        - **Estado Atual:** Monitoramento funcional, **remediação inativa** para Authentik.
    - **Causa Raiz (Root Cause):**
        - A coleção `firix/authentik` utiliza Regex compatível com versões anteriores do Authentik.
        - O Authentik 2025 alterou o formato dos eventos `login_failed`, impedindo a extração de IP (`source_ip`).
        - **Conclusão:** Limitação da coleção da comunidade, não da infraestrutura local.


- **Integração OPNsense (Bouncer):**
    - **Plugin `os-crowdsec`:** Superada falha de validação da GUI (que exige campos locais mesmo para LAPI remota) usando configuração "fake" (127.0.0.1) e edição manual do `/usr/local/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml` via SSH.
    - **Validação:** Teste com IP `1.1.1.1` resultou em bloqueio imediato na tabela `crowdsec_blocklists`.
## 2026-01-22
**Status:** ✅ Sucesso (Observability Repair & GitOps Level 2)

**Foco:** Correção de Métricas do Traefik, Ressurreição do Loki (Config V3) e Implementação de Dashboard as Code.

- **Correção de Métricas (Traefik v3):**
    - **Sintoma:** O Dashboard do Traefik no Grafana não exibia dados ("No Data"), apesar da porta 8082 estar exposta.
    - **Diagnóstico:** O Traefik estava gerando métricas, mas não estava vinculado ao EntryPoint dedicado. O endpoint `/metrics` retornava 404.
    - **Correção:** Adicionado `--metrics.prometheus.entryPoint=metrics` no `docker-compose.yml`.
    - **Validação:** `curl http://10.10.30.10:8082/metrics` passou a retornar o payload do Prometheus.
    - **Aprendizado:** Grafana vazio muitas vezes é apenas o *Time Range* errado. Alterado de "Last 6 hours" para "Last 5 minutes" para visualizar dados recentes.

- **Troubleshooting do Loki (Crash Loop):**
    - **Incidente:** O Grafana exibia erro `Live tailing was stopped... undefined` e o container do Loki reiniciava a cada 10 segundos.
    - **Causa Raiz (Depreciação):** O arquivo de configuração `local-config.yaml` utilizava parâmetros da versão 2.x incompatíveis com a imagem `loki:3.6.3`.
    - **Correções Aplicadas:**
        1.  **Shared Store:** Removida a linha `shared_store: filesystem` (o Loki v3 infere isso automaticamente).
        2.  **Compactor:** Adicionado `delete_request_store: filesystem` no bloco do `compactor` (Obrigatório quando `retention_enabled` é true).
    - **Recuperação do Agente:** O container `alloy` (coletor) havia desistido de enviar logs durante a falha. Um `docker compose restart alloy` restabeleceu o fluxo de logs para o Grafana.

- **Implementação de Dashboard as Code (Imutabilidade):**
    - **Objetivo:** Eliminar o "ClickOps". Dashboards devem ser arquivos no Git, não configurações manuais no banco de dados.
    - **Arquitetura:**
        - Criada estrutura separada: `provisioning/dashboards` (Configuração do Provider) e `dashboards/` (Arquivos JSON).
        - Mapeados volumes no `docker-compose.yml` do Grafana.
    - **Desafio de Deploy (Ansible):**
        - *Erro 1:* Execução do Ansible fora da raiz (`/opt/homelab`), causando falha na leitura do `ansible.cfg` e inventário.
        - *Erro 2:* Estrutura de pastas inconsistente no repositório de origem (Arch Linux), misturando JSONs com configs YAML.
    - **Solução:** Reorganização das pastas no Git local (`mv *.json dashboards/`) e execução correta do Ansible.
    - **Resultado:** Dashboards marcados como "Provisioned". O Grafana agora impede a exclusão manual ("Cannot be deleted"), garantindo integridade da infraestrutura.

- **Conceitos Adotados/Aprendidos:**
    - **Método U.S.E. (Utilization, Saturation, Errors):** Aplicado para análise de Hardware (Node Exporter).
    - **Método R.E.D. (Rate, Errors, Duration):** Aplicado para análise de Serviços.
## 2026-01-19
**Status:** ✅ Sucesso (DNS High Availability)

**Foco:** Implementação de Redundância de DNS, Hardening Forense e Correção de Roteamento.

- **Implementação do DNS Secundário (Raspberry Pi):**
    - **Objetivo:** Garantir resolução de nomes mesmo se o LXC Alpine falhar.
    - **Deploy:** Criado playbook `setup_rpi_adguard.yml` instalando AdGuard Home v0.107.56.
    - **Desafio de Sintaxe (YAML Hell):**
        - *Sintoma:* O serviço entrava em loop de reinício com erro `cannot unmarshal !!seq into string`.
        - *Causa:* O binário do AdGuard é estrito com indentação e tipos (Lista vs String) no arquivo de configuração, especialmente nas chaves `bind_hosts`.
        - *Solução:* Adoção de sintaxe YAML Inline (ex: `bind_hosts: [ "0.0.0.0" ]`) e definição explícita de `schema_version: 29` no template Ansible.
    - **Desafio de Validação (Init Stats):**
        - *Erro:* `fatal: init stats: unsupported interval: less than an hour`.
        - *Solução:* Mesmo com estatísticas desativadas (`enabled: false`), o validador exige um intervalo válido. Configurado `interval: 24h` para satisfazer o check, mantendo a coleta desligada.

- **Hardening Forense (Zero Footprint):**
    - **Arquitetura:** O Raspberry Pi foi configurado para **não persistir** nenhum dado de navegação no cartão SD.
    - **RAM Disk (Tmpfs):** O diretório de dados (`/opt/AdGuardHome/data`) é montado em RAM.
    - **Permissões Estritas:** Configurado `mode=0700` no mount point.
        - *Validação:* `df -h` confirma `tmpfs`, e acesso via usuário comum retorna `Permission denied`. Apenas root acessa a memória do processo.
    - **Logs:** `querylog` e `statistics` desativados na configuração. `journald` silenciado via `StandardOutput=null` no Systemd.

- **Correção de Infraestrutura de Rede (OPNsense):**
    - **Incidente:** O Arch Linux (VLAN Trusted) conseguia pingar o Gateway, mas falhava ao acessar a internet (`Destination Host Unreachable` para 1.1.1.1).
    - **Diagnóstico:** O campo **Gateway** no escopo DHCPv4 da interface Trusted estava definido como `None`. Os clientes recebiam IP mas não rota default.
    - **Correção:** Definido Gateway para `10.10.20.1` (IP do OPNsense na VLAN). Conectividade restaurada imediatamente.
    - **Ajuste de DNS System:** Removidos gateways associados aos DNS Servers em *System > Settings > General*, corrigindo o erro `You can not assign a gateway to DNS server which is on a directly connected network`.

- **Teste de Failover (Chaos Engineering):**
    - **Cenário:** Container do AdGuard Primário (`10.10.30.5`) desligado intencionalmente.
    - **Resultado:**
        1. O cliente (Arch) detectou timeout no primário.
        2. Automaticamente chaveou para o secundário (`192.168.0.5`).
        3. `dig google.com` confirmou resposta vinda do Pi.
        4. Navegação continuou fluida.
    - **Conclusão:** A redundância de DNS está operante e transparente.
## 2026-01-18
**Status:** ✅ Sucesso (Hardening & Edge Observability)

**Foco:** Segurança do Raspberry Pi e Integração com Prometheus Central

- **Hardening do Raspberry Pi (Management Node):**
    - **Integração Ansible:** Adicionado grupo `[rpi]` ao inventário e configurada troca de chaves SSH com o controlador.
    - **Playbook Dedicado:** Criado `hardening_rpi.yml`, derivado do padrão Debian, mas adaptado para hardware físico.
        - *Ajuste Tático:* Removido pacote `libraspberrypi-bin` que não está disponível nos repositórios padrão do Debian 13 (Trixie), evitando falha de provisionamento.
    - **Resultados:**
        - SSH configurado para aceitar **apenas chaves** (Senha removida).
        - Fail2Ban ativo protegendo a porta 22 contra ataques na rede interna/VPN.
        - Timezone sincronizado para `America/Sao_Paulo`.

- **Expansão da Observabilidade (Prometheus):**
    - **Agente:** Instalado `prometheus-node-exporter` no Raspberry Pi via Ansible.
    - **Coleta (Scrape):** Configurado Prometheus no DockerHost para ler métricas do Pi (`192.168.0.5:9100`).
    - **Troubleshooting (Config Reload):**
        - *Sintoma:* O Ansible atualizou o arquivo `prometheus.yml` no DockerHost, mas o Grafana não mostrava os dados.
        - *Causa:* O serviço Prometheus dentro do container não recarregou a configuração automaticamente apenas com a mudança do arquivo.
        - *Solução:* Executado `docker restart prometheus`.
    - **Validação:** Query `up{job="rpi-edge"}` retornou `1` no Grafana. O Pi agora é observável (CPU, RAM, Disco, Temperatura).
## 2026-01-17
**Status:** 🔄 Pivotagem de Hardware (UPS)

**Foco:** Engenharia Reversa do Protocolo do Nobreak e Decisão de Devolução.

- **Diagnóstico Profundo do Nobreak (Ragtech M2):**
    - **Identificação:** Chipset Microchip detectado (`ID 04d8:000a`). Interface serial emulada em `/dev/ttyACM0`.
    - **Tentativas de Driver (NUT):**
        - `nutdrv_qx`: Testados dialetos `megatec`, `krauler` e `voltronic`. Resultado: `Device not supported`.
        - `blazer_ser`: Testadas velocidades 2400, 9600 e 460800 baud. Resultado: Timeout/No supported UPS detected.
    - **Autópsia (Python Script):**
        - Criado script para envio de comandos brutos (Raw Serial) com sinal DTR/RTS forçado.
        - **Resultado:** O dispositivo respondeu com o byte `\xca` (Hex 202) para qualquer comando padrão ASCII (`Q1`, `I`).
    - **Conclusão Técnica:** A Ragtech implementou um protocolo binário proprietário/fechado neste lote de chips, incompatível com os padrões abertos (Megatec/Voltronic) utilizados pelo NUT.

- **Decisão de Negócios:**
    - O uso de scripts de terceiros ("gambiarras" em Python) para traduzir o protocolo foi considerado, mas descartado por violar o princípio de confiabilidade para infraestrutura crítica.
    - **Ação:** Iniciado processo de devolução do produto por arrependimento.
    - **Próximos Passos:** Aquisição de um novo Nobreak (APC ou NHS) com compatibilidade nativa Linux comprovada.

- **Limpeza do Raspberry Pi:**
    - Removidos pacotes de diagnóstico (`python3-serial`, `nut-client`).
    - Removidas regras Udev e configurações do NUT.
    - O Pi permanece operante como nó de gerenciamento, aguardando o novo UPS.

## 2026-01-16
**Status:** ✅ Sucesso (Recuperação do Management Node)

**Foco:** Reinstalação do Raspberry Pi, Correção de I/O e Configuração de RTC.

- **Recuperação do Raspberry Pi (OS & Storage):**
    - **Problema:** Boot loop e erros de I/O (`uas_eh_device_reset_handler`) persistiam mesmo com a nova fonte.
    - **Causa Raiz:** Incompatibilidade do driver UAS (USB Attached SCSI) do Kernel Linux com o controlador JMicron (`152d:0583`) do case SSD.
    - **Solução (Quirks):** Adicionado `usb-storage.quirks=152d:0583:u` ao `/boot/cmdline.txt`, forçando o modo "Bulk-Only Transport" (mais lento, porém estável).
    - **Resultado:** Sistema estável, boot rápido e zero erros de I/O.

- **Configuração de Rede (Debian 13/Bookworm):**
    - Abandonado `dhcpcd` (obsoleto). Configurado IP Estático `192.168.0.5` utilizando **NetworkManager** (`nmcli`).

- **Relógio de Hardware (RTC DS3231):**
    - **Desafio:** O Debian 13 mudou a localização dos arquivos de configuração e removeu scripts antigos de hwclock.
    - **Implementação:**
        1. Ativado I2C via `raspi-config`.
        2. Adicionado overlay `dtoverlay=i2c-rtc,ds3231` em `/boot/firmware/config.txt`.
        3. Removido pacote `fake-hwclock` para evitar conflitos.
        4. Sincronização realizada via `hwclock -w`.
    - **Validação:** `hwclock -r` retorna a data correta persistente, garantindo logs precisos mesmo sem internet.
## 2026-01-15
**Status:** ⏸️ Pausa Forçada (Hardware Bloqueante)

**Foco:** Provisionamento do Raspberry Pi, Teste de Carga do Nobreak e Gestão de Crise de Hardware.

- **Incidente Elétrico (Nobreak):**
    - **Ação:** (Agi sem pensar) Realizado teste de carga conectando uma chaleira elétrica (~1850W) nas tomadas do Nobreak Ragtech.
    - **Resultado:** O equipamento entrou em estado de alarme imediato (Bip contínuo/rápido), indicando **Sobrecarga (Overload)**.
    - **Diagnóstico:** A potência da carga resistiva excedeu largamente a capacidade nominal (840W) do inversor.
    - **Correção:** Carga removida. Nobreak conectado à rede elétrica sem dispositivos de saída para ciclo de carga inicial de 24 horas (recomendação do manual).

- **Provisionamento do Pi (Software):**
    - Instalado `rpi-imager` no Arch Linux.
    - Gravada imagem **Raspberry Pi OS Lite (64-bit)** no SSD via USB 3.0.
    - **Configuração Headless:** Definido hostname `rpi`, usuário `fajre` e SSH habilitado via configurações avançadas do Imager.
    - Excelente programa, btw.

- **Incidente de Suprimentos (Fonte do Pi):**
    - A fonte adquirida ("Kit Gamer U1002") chegou com conector incompatível (P4/Micro-B em vez de USB-C). Devolução iniciada.
    - **Workaround Falho:** Tentativa de boot utilizando carregador de celular (Xiaomi).
    - **Sintoma:** O Pi ligou, mas o monitor exibiu erros de I/O cíclicos: `scsi host0: uas_eh_device_reset_handler`.
    - **Causa Raiz:** **Brownout**. O carregador não suportou o pico de corrente exigido pelo SSD via USB 3.0, causando queda de tensão e desligamento do controlador de disco.
    - **Ação:** Comprada fonte **CanaKit 3.5A** (Padrão oficial) com filtro de ruído. Instalação suspensa até a chegada (Sexta-feira, 16/01).

- **Decisão Arquitetural (Segurança):**
    - Formalizada a decisão de **NÃO utilizar criptografia LUKS** no Raspberry Pi.
    - **Justificativa:** O Pi é um dispositivo de recuperação de desastres. Exigir senha de boot criaria um deadlock ("Ovo e Galinha") onde o dispositivo necessário para liberar o acesso remoto estaria ele mesmo inacessível, e também não há nada tão sensível para esconder (Split Storage, ver melhor a explicação em docs/services/rpi.md Segurança será garantida por isolamento de rede e ACLs na VPN.
## 2026-01-14
**Status:** ✅ Sucesso (Observability Phase 1 & PKI Pivot)

**Foco:** Implementação do Núcleo de Observabilidade, Pivotagem de PKI e Hardening de Rede.

- **Arquitetura de Observabilidade (LGM Stack):**
    - Implantado stack central no DockerHost via Ansible:
        - **Prometheus (v3.9):** Scrape local (15 dias de retenção).
        - **Loki (v3.6):** Recebendo logs. Configurado `max_streams_per_user` para evitar OOM.
        - **Grafana (v12.3):** Autenticação delegada ao Authentik (ForwardAuth).
        - **Alloy:** Agente unificado. Lê logs do host via `journald` e containers via arquivos `json-file`.
        - **Ntfy:** Gateway de notificações push (Self-hosted).
    - **Docker Logging:** Driver alterado globalmente para `json-file` (rotação 3x10MB) para permitir leitura direta de disco pelo Alloy, reduzindo overhead no daemon.

- **Pivotagem de PKI (SSL/TLS):**
    - **Erro Conceitual:** Assumiu-se inicialmente que o Traefik gerenciava uma PKI interna (Step-CA). Os logs revelaram o uso de "Default Certs" autoassinados, rejeitados pelo Android.
    - **Solução Pragmática:** Implementada CA Local via `mkcert` (Trust-on-device).
        - Gerado certificado Wildcard `*.home` e IP SAN `10.10.30.10`.
        - **Security Decision:** Chaves privadas (`.key`) transferidas via SCP (Out-of-band), estritamente fora do Git.
        - **Trust:** `rootCA.pem` instalada manualmente no Android e Arch Linux.

- **Resolução de Roteamento (Traefik 504 Timeout):**
    - **Incidente:** Gateway Timeout ao acessar Ntfy via Ingress.
    - **Causa:** Ambivalência de roteamento em containers multi-rede (`monitoring` vs `proxy`).
    - **Correção:** Fixada rede de saída via label `traefik.docker.network=proxy` e porta de serviço explícita `loadbalancer.server.port=80`.

- **Hardening de Automação (Ansible):**
    - **Segurança:** Implementado `vars_prompt` para inserção de segredos em runtime, evitando vazamento em histórico de shell.
    - **Dependências:** Adicionado `rsync` ao `hardening_debian.yml` para viabilizar módulo `synchronize`.
    - **Escopo:** Restrita a configuração de Docker apenas ao grupo `dockerhost`, preservando a integridade da VM Vault (Pure Debian).

- **Backup:**
    - Diretório `/opt/monitoring` incluído na política de backup do Restic. Snapshot validado.
## 2026-01-11
**Status:** ✅ Sucesso (Host Hardening & Defense in Depth)

**Foco:** Proteção contra Brute-Force (Fail2Ban) e Refinamento de SSH

- **Hardening do Proxmox (Host Físico):**
    - Criado playbook dedicado `hardening_proxmox.yml`.
    - **Proteção Web UI:** Implementado Fail2Ban monitorando logs do `pvedaemon` e `pveproxy` (Regex duplo) para bloquear tentativas de login na porta 8006.
    - **Backend Otimizado:** Configurado para ler logs diretamente do `systemd/journald` em vez de arquivos de texto.
    - **SSH:** Configurado `PermitRootLogin prohibit-password` (Apenas Chave).
- **Hardening Debian (DockerHost & Vault):**
    - Refatorado playbook `hardening_debian.yml` para padrões de produção.
    - **Fail2Ban:** Configurado com `mode = aggressive` no SSH para detectar falhas de pré-autenticação.
    - **Whitelist de Rede:** Adicionada regra `ignoreip` para a rede de Gestão (10.10.10.x) e Trusted (10.10.20.x), prevenindo que automações ou erros de digitação causem auto-lockout.
    - **SSH Moderno:** Substituído parâmetro legado `ChallengeResponseAuthentication` por `KbdInteractiveAuthentication no` (Padrão Debian 12+).
    - **Estabilidade:** Alterada política de atualização de `dist-upgrade` para `safe-upgrade` para evitar remoção acidental de pacotes críticos.
- **Validação:**
    - Testes de conexão confirmaram que chaves SSH continuam funcionando.
    - Status do Fail2Ban validado em todos os nós (`jail sshd` ativo e backend systemd carregado).
## 2026-01-10
**Status:** ✅ Sucesso (Hardening & Optimization)

**Foco:** Rotação de Credenciais, Otimização de DNS e Correção de Custos de Backup

- **Rotação de Credenciais (Security Sprint):**
    - Substituídas todas as senhas fracas/compartilhadas por senhas únicas.
    - **Escopo:** Proxmox Host, OPNsense, DockerHost, Vault VM, Management LXC, AdGuard LXC, AdGuard Home (serviço) e Vaultwarden.
    - **Armazenamento:** Todas as credenciais salvas no Vaultwarden.
- **Correção de Provisionamento Alpine:**
    - Identificado que o serviço SSH não iniciava automaticamente após instalação via Ansible em containers Alpine (OpenRC).
    - **Fix:** Adicionada tarefa explícita `service: name=sshd state=started enabled=yes` no playbook `hardening_alpine.yml`.
- **Otimização do AdGuard Home:**
    - **Performance:** Upstream DNS alterado para "Parallel Requests" (Quad9 + Cloudflare) e ativado "Optimistic Caching" para respostas instantâneas.
    - **Privacidade/Segurança:** Ativado DNSSEC e desabilitada resolução IPv6 (foco em estabilidade IPv4 na LAN).
    - **Bloqueio:** Adicionada lista `OISD Big` (famosa por zero false-positives) e ativada lista `AdAway`.
    - **Logs:** Retenção reduzida para 7 dias (Query) e 7 dias (Stats) para privacidade e economia de disco.
- **Backblaze B2 (Cost Management):**
    - Ajustada política de ciclo de vida do bucket para `Keep only the last version of the file`.
    - **Justificativa:** O Restic já gerencia o versionamento e snapshots internamente. A configuração padrão do B2 ("Keep all versions") manteria arquivos deletados pelo `prune` cobrando armazenamento eternamente.
## 2026-01-09
**Status:** ✅ Sucesso (GitOps, Hardening & Disaster Recovery)

**Foco:** Transformação da infraestrutura em Código (IaC), Segurança e Implementação de Backup Criptografado

- **Migração para GitOps (DockerHost):**
    - **Adoção de Infraestrutura:** Importadas configurações reais (`/opt/services/*`) via SCP para o repositório Git, padronizando a estrutura em `configuration/dockerhost/{serviço}`.
    - **Automação (Ansible):** Criado playbook `manage_stacks.yml` atuando como "Fonte da Verdade".
    - **Lógica Híbrida:** - Serviços simples (Traefik, Whoami) iniciados via módulo Docker direto.
        - Serviços críticos (Authentik, Vaultwarden) migrados para **Systemd Units** (`.service`) para garantir a injeção de segredos via script `start-with-vault.sh`.

- **Hardening e Segurança:**
    - **Segregação de OS:** Criados playbooks distintos: `hardening_debian.yml` (DockerHost, Vault) e `hardening_alpine.yml` (Management, AdGuard).
    - **Lockout Incident (Aprendizado):** - *Erro:* O script Alpine definiu `PermitRootLogin no`. Como o Ansible conecta como root, houve bloqueio de acesso ao AdGuard.
        - *Solução:* Acesso via Console Proxmox, alteração manual para `prohibit-password` e correção definitiva no playbook.

- **Backup do Firewall (OPNsense):**
    - **Plugin:** Implementado `os-git-backup`.
    - **Fix de Compatibilidade:** Gerado par de chaves **RSA (PEM Legacy)** e ajustada URL para `ssh://github.com/...` para contornar rejeição de chaves Ed25519 pelo plugin.
    - **Resultado:** Backup automático e versionado da configuração XML para repositório privado a cada alteração.

- **Backup de Dados (Restic + Backblaze B2):**
    - **Arquitetura Distribuída:** Cada host possui seu próprio repositório isolado e criptografado no Bucket B2 (`b2:bucket:/host`).
    - **Controle de Acesso de Rede (OPNsense):**
        - Configurado **Schedule** `HorarioBackupVault` (03:59 - 04:30) com validade até o fim de 2026.
        - Criada regra de firewall na VLAN 40 permitindo saída de dados apenas nesta janela temporal, mantendo o Vault isolado (Air-gapped) no restante do dia.
    - **Vault Strategy:** Criada Policy específica e Token periódico com **Auto-Renovação** via script diário. Snapshots (`raft-YYYYMMDD.snap`) são gerados localmente antes do upload.
    - **Automação:** Playbook `setup_backup.yml` auditado e Cronjobs distribuídos para evitar gargalo de rede.

- **Disaster Recovery (Fire Drill):**
    - **Simulação:** Arquivo `docker-compose.yml` do serviço `whoami` deletado intencionalmente no DockerHost.
    - **Execução:**
        - *Falha Inicial:* Uso de `sudo` dropou as variáveis de ambiente do Restic.
        - *Correção:* Execução como root nativo carregando `source /etc/restic-env.sh`.
        - Comando: `restic restore <snapshot_id> --target / --include ...`
    - **Resultado:** Arquivo recuperado com sucesso, permissões mantidas. Backup validado.
- **Correção de Timezone (Sincronização de Relógios):**
    - Identificada discrepância de horários entre Hosts (EST/UTC) e Proxmox (-03).
    - **Ação:** Integrada a correção diretamente nos playbooks de hardening, eliminando a necessidade de scripts avulsos.
    - **Configuração:**
        - Timezone definido para `America/Sao_Paulo` em todos os nós.
        - **Alpine:** Instalação automática do pacote `tzdata` e link manual do `/etc/localtime`.
        - **Debian:** Configuração via módulo nativo `timezone`.
    - **Resultado:** Logs e Backups agora possuem timestamps consistentes (-03 BRT).
## 2026-01-08
**Status:** ✅ Sucesso (Infrastructure as Code)

**Foco:** Consolidação do DockerHost e Migração para GitOps

- **Centralização de Configuração:**
    - Realizada a importação ("Adoption") de todas as configurações manuais do DockerHost para o repositório Git.
    - Estrutura padronizada em `configuration/dockerhost/{serviço}`.
- **Automação (Ansible):**
    - Criado playbook `manage_stacks.yml` que atua como "Fonte da Verdade".
    - O playbook gerencia a sincronização de arquivos, permissões e execução dos containers.
- **Gestão de Segredos:**
    - Implementada lógica híbrida no Ansible:
        - Serviços simples (Traefik, Whoami) iniciados via módulo Docker direto.
        - Serviços críticos (Authentik, Vaultwarden) gerenciados via Systemd Units (`authentik-vault.service`) para garantir a injeção de segredos do Vault via script `start-with-vault.sh`.
- **Resultado:**
    - O servidor DockerHost agora é gerenciado remotamente. Alterações são feitas no Git e aplicadas via Ansible, garantindo consistência e eliminando "Snowflake Servers".
## 2026-01-07
**Status:** ✅ Sucesso (Automação & Management Plane)

**Foco:** Criação da Torre de Controle (Ansible) e Saneamento de Rede

- **Infraestrutura de Rede (VLAN 10 - MGMT):**
    - Criada VLAN 10 no OPNsense (`10.10.10.1/24`) atribuída à interface `vtnet1` (Trunk), agrupando-a com as redes TRUSTED/SERVER.
    - **Decisão Arquitetural:** Mantida a separação física/lógica onde a VLAN 40 (Vault) reside na `vtnet0` (LAN Dedicada) e as demais na `vtnet1` (Trunk), respeitando o isolamento de segurança.
    - **Troubleshooting (Bloqueio L2):** O container na VLAN 10 não conseguia comunicar com o Gateway.
        - *Causa:* A interface de rede da VM OPNsense no Proxmox (`net1`) possuía um filtro de VLANs (`trunks=20;30;50`) que bloqueava a tag 10.
        - *Correção:* Editado `/etc/pve/qemu-server/100.conf` para incluir a VLAN 10 na lista de permitidos.
- **Management Node (LXC 102):**
    - Criado Container Alpine Linux (102 - Management) na VLAN 10.
    - **Configuração:** IP Estático `10.10.10.10`, acesso SSH via chave.
    - **Tooling:** Instalado Ansible (Core 2.17+), Restic, Terraform e Git.
- **Automação (Ansible):**
    - **Bootstrap:** Repositório `homelab` clonado em `/opt/homelab`.
    - **Conectividade:** Chave SSH do Container autorizada no DockerHost (`10.10.30.10`).
    - **Correção no DockerHost:** O Debian Minimal não possuía `sudo`. Instalado pacote manualmente e configurado `NOPASSWD` para o usuário de automação, destravando a execução de playbooks com `become: yes`.
    - **Primeiro Run:** Executado playbook `hardening_debian.yml` com sucesso.
        - *Ação:* Atualização do OS, instalação de ferramentas (fail2ban, htop, ncdu) e remoção intencional do UFW (para evitar conflito com Docker/Traefik).
## 2026-01-05
**Status:** ✅ Sucesso (Disaster Recovery & Validation) e adição do primeiro serviço (Vaultwarden)

**Foco:** Teste de Resiliência e Recuperação de Falha Humana

- **O Incidente (Human Error):**
    - Durante troubleshooting de acesso, executei `docker compose down -v` no stack do Authentik.
    - **Impacto:** O flag `-v` deletou o volume persistente do PostgreSQL. O banco de dados de identidade foi zerado.
    - **Sintomas:** Perda de usuários, grupos, policies e configurações de Providers. O Vault e Traefik permaneceram intactos, mas o "porteiro" (Authentik) perdeu a memória.
- **A Recuperação (Cold Recovery):**
    - Recriado usuário admin (`akadmin`).
    - Recriados os Providers e Applications para Traefik e Vault.
    - Restaurada a Policy Python (`infra-admins`) para RBAC.
    - **Tempo de Recuperação:** ~15 minutos.
- **Teste de Fogo (Reboot do Host):**
    - Executado reboot total do servidor físico para validar a automação criada ontem.
    - **Comportamento Observado:**
        1.  Proxmox subiu e pediu senha LUKS (OK), desbloqueio realizado via SSH do Dropbear.
        2.  VMs iniciaram na ordem correta (OPNsense -> DNS -> Vault -> DockerHost).
        3.  **Resiliência:** O serviço `authentik-vault` no DockerHost falhou ao tentar conectar no Vault (que estava Selado). O Systemd entrou em loop de retry (OK).
        4.  **Intervenção:** Realizado Unseal manual do Vault via SSH.
        5.  **Sucesso:** Imediatamente após o Unseal, o script do DockerHost obteve a senha do banco e subiu o Authentik automaticamente.
- **Conclusão:** A arquitetura de *AppRole* com injeção de segredos em RAM provou-se resiliente a reboots e segura. O incidente reforçou a necessidade de **não usar** `-v` em produção e a urgência de configurar backups automatizados do banco PostgreSQL.
- **Deploy de Aplicação (Vaultwarden):**
    - **Objetivo:** Hospedar gerenciador de senhas soberano para validar a arquitetura de segredos (AppRole) e substituir dependência de nuvem.
    - **Decisões Técnicas:**
        - **Database:** Escolhido **SQLite** para reduzir complexidade e facilitar backup (arquivo único), em vez de adicionar overhead com PostgreSQL.
        - **Ingress:** Configuração híbrida no Traefik:
            1.  `vaultwarden.home/` (API/Web): Acesso público (interno) para compatibilidade com Apps Mobile.
            2.  `vaultwarden.home/admin`: Protegido por Middleware Authentik (`infra-admins` only).
    - **Automação:**
        - Criado script `start-with-vault.sh` específico.
        - O DockerHost autentica no Vault via AppRole, busca o `ADMIN_TOKEN` e injeta no container.
        - **Validação de Segurança:** O token não existe em texto plano no disco (apenas o SecretID com permissão 600).
    - **Testes:**
        - **Web/Browser Extension:** Sucesso total. Login, sincronização e acesso ao Admin (via Authentik) funcionando.
        - **Mobile (Android):** O App Bitwarden recusou conexão devido ao certificado autoassinado (SSL Handshake Error).
            - *Workaround:* Validado via extensão. A correção definitiva virá com a implementação de CA confiável no Android ou Let's Encrypt.
    - **Backup:** Procedimento de backup semanal (JSON Criptografado) mantido.
## 2026-01-04
**Status:** ✅ Sucesso (Refatoração de Segurança)

**Foco:** Migração do Vault para VM Dedicada (Zero Trust Real)

- **Correção de Rumo:**
    - A implementação inicial (Container) violava a política de segmentação da VLAN 40.
    - **Ação:** Destruí o container e provisionei a VM 106 (`Vault`) isolada na VLAN 40.
- **Infraestrutura:**
    - **OPNsense:** Criada VLAN 40 e regra de firewall permitindo apenas `Source: DockerHost` -> `Dest: Vault:8200`.
    - **Traefik:** Configurado *File Provider* para rotear `vault.home` para `http://10.10.40.10:8200` via arquivo dinâmico.
- **Vault Setup:**
    - Instalação nativa (apt) no Debian 13.
    - Configurado `api_addr = "https://vault.home"` para garantir que redirecionamentos de UI passem pelo Proxy reverso.
    - **Resultado:** Unseal realizado com sucesso, chaves salvas e interface protegida pelo Authentik.
- **Hardening Final & Validação (Pós-Migração):**
    - **Host Firewall (Defense in Depth):** Ativado UFW na VM Vault para não depender apenas do OPNsense.
        - Regras aplicadas: `Allow 8200 from 10.10.30.10` e `Allow 22 from Trusted/Mgmt`.
        - Teste de movimento lateral (SSH do DockerHost para Vault): **Bloqueado com sucesso**.
    - **Isolamento de Internet:** Regra `Temp Install Vault` desativada no OPNsense.
        - Teste: `ping 1.1.1.1` a partir do Vault falha (Timeout). A VM está isolada.
    - **Troubleshooting de Rede:**
        - Resolvido problema onde a VM não conectava à internet para updates iniciais.
        - **Causa:** Falta de regra de **Outbound NAT** para a nova VLAN 40. Corrigido adicionando regra manual no OPNsense.
- **Integração Zero Trust (Vault + Authentik):**
    - **Desafio:** O DockerHost precisava ler segredos sem intervenção humana, mas o Vault inicia trancado (Sealed) após reboot.
    - **Solução:**
        1.  **Identidade:** Configurei **AppRole** no Vault. O DockerHost possui um "crachá" (SecretID) protegido em `/etc/vault/dockerhost.secretid` (root-only).
        2.  **Rede:** Ajustei o DNS do DockerHost para usar o AdGuard (`10.10.30.5`) via `systemd-resolved`, garantindo resolução de `vault.home` sem hacks manuais.
        3.  **Automação:** Desenvolvi o script `start-with-vault.sh` que autentica, baixa a senha do PostgreSQL e sobe o stack.
    - **Teste de Resiliência:**
        - Realizado reinício físico do servidor (Cold Boot).
        - O Vault subiu selado. O serviço `authentik-vault` entrou em loop de retry no DockerHost (comprovando resiliência).
        - Após destrancar o Vault manualmente via SSH (lembrando de definir `export VAULT_ADDR='http://127.0.0.1:8200'`), o DockerHost detectou o sucesso automaticamente e subiu os containers do Authentik em menos de 10 segundos.
    - **Resultado:** Infraestrutura resiliente a falhas de energia e sem segredos em texto puro no disco.
## 2026-01-03
**Status:** ✅ Sucesso (Secret Management)

**Foco:** Implementação do HashiCorp Vault

- **Decisão de Versão:**
    - Optado por **Vault v1.21.1** (Latest Stable), garantindo correções de segurança recentes.
- **Implementação:**
    - Backend de armazenamento: **Raft** (Integrated Storage) - elimina dependência do Consul.
    - Proteção de Ingress: Middleware `authentik@docker` aplicado no router do Vault. Apenas admins autenticados chegam na tela de login do cofre.
- **Cerimônia de Inicialização (Unseal):**
    - Executada inicialização com **Shamir's Secret Sharing**.
    - **Configuração:** 5 Key Shares, Threshold de 3 chaves para desbloqueio.
    - **Root Token:** Gerado e armazenado com segurança máxima (Bitwarden, depois para o Vaultwarden) junto com as 5 chaves de unseal.
- **Estado Final:**
    - Vault operacional em `https://vault.home`.
    - Banco de dados criptografado em repouso.
    - Requer desbloqueio manual (3 chaves) a cada reinicialização do container.
## 2026-01-02 (Parte 4)
**Status:** ✅ Sucesso (Hardening RBAC)

**Foco:** Restrição de Acesso via Policy (Python)

- **Objetivo:** Impedir que qualquer usuário logado no Authentik (mesmo sem privilégios) acesse o painel administrativo do Traefik. Apenas a equipe de infraestrutura deve ter acesso.
- **Implementação:**
    - Criado grupo `infra-admins` no Authentik e incluído o usuário administrador.
    - Criada uma **Expression Policy** (Python) para validar a pertinência ao grupo:
      ```python
      return ak_is_group_member(request.user, name="infra-admins")
      ```
    - Vinculada a policy ao aplicativo `Traefik Dashboard` com prioridade 0.
- **Validação:**
    - Login com admin: **Sucesso** (Acesso liberado).
    - Login com usuário comum: **Bloqueado** (Mensagem "Permission Denied" exibida pelo Authentik).
## 2026-01-02 (Parte 3)
**Status:** ✅ Sucesso (Identity Provider & Zero Trust)

**Foco:** Implementação do Authentik e Integração com Traefik (ForwardAuth)

- **Desafio 1 (Erro Operacional):**
    - Durante a configuração dos arquivos `docker-compose.yml`, houve uma **sobrescrita acidental** do arquivo do Authentik com o conteúdo do Traefik. Isso causou a queda de ambos os serviços.
    - *Recuperação:* Foi necessário restaurar manualmente os manifestos YAML corretos em `/opt/auth/authentik` e `/opt/traefik` e recriar os containers (`force-recreate`).
- **Desafio 2 (O Erro 404 no Callback):**
    - Após configurar o middleware, o fluxo de login iniciava, mas falhava no retorno (`/outpost.goauthentik.io/callback...`) com erro 404 do Traefik.
    - **Causa Técnica:** O Traefik bloqueava a URL de callback porque ela não correspondia à regra restrita do Dashboard (`PathPrefix(/dashboard)`).
- **Solução Definitiva (Global Callback Route):**
    - Adicionada uma Label no serviço do Authentik criando um Router dedicado: `Rule=PathPrefix(/outpost.goauthentik.io/)`.
    - Isso instrui o Traefik a interceptar *qualquer* requisição de callback do Authentik, independente do domínio, e encaminhá-la para o container do IdP.
- **Resultado:**
    - Acesso a `https://traefik.home/dashboard/` redireciona para `auth.home`, exige credenciais e retorna com sucesso.
    - Porta 8080 do Traefik foi fechada definitivamente.
## 2026-01-02 (Parte 2)
**Status:** ✅ Sucesso (Hardening)

**Foco:** Segurança do DockerHost e Padronização

- **Motivação:** Antes de implementar a camada de identidade (Authentik), identifiquei que o Traefik mantinha acesso direto e irrestrito ao `docker.sock`. Isso violava o princípio do menor privilégio (Security by Design).
- **Ações de Mitigação:**
    - **Socket Proxy:** Interpus um proxy que filtra chamadas de API. Agora o Traefik só tem permissão para listar containers (`GET`). Comandos destrutivos ou de criação (`POST`, `DELETE`) são bloqueados silenciosamente.
    - **Resiliência de Disco:** Configurei rotação de logs global no Docker Daemon (Max 3 arquivos de 10MB) para evitar que serviços verbosos lotem o armazenamento de 32GB.
    - **OS Patching:** Debian configurado para aplicar patches de segurança automaticamente (`unattended-upgrades`).
    - **Organização:** Migrei serviços dispersos para a hierarquia `/opt/services/` e padronizei o ownership para o usuário comum, removendo a necessidade de operar arquivos como root.
## 2026-01-02
**Status:** ✅ Sucesso Definitivo (Traefik v3.6)

**Foco:** Upgrade para Traefik v3.6 (Latest Stable) e Validação de Ingress

- **Decisão Estratégica:**
    - Optado por não manter a versão legado (v2.11) e migrar imediatamente para **Traefik v3.6** para evitar dívida técnica futura (EOL em Fev/2026).
- **Implementação (The Fix):**
    - Configurado container `traefik:v3.6`.
    - Mantida a variável de ambiente `DOCKER_API_VERSION=1.45`.
    - **Resultado:** A biblioteca client do Traefik v3 respeitou a variável e ignorou a negociação de versão falha, conectando-se perfeitamente ao Docker Engine do Debian 13.
- **Validação Técnica (Headers):**
    - `whoami` reportou `X-Forwarded-Proto: https` (Terminação SSL OK).
    - `X-Real-Ip: 10.10.20.101` (Roteamento de VLANs transparente, sem mascaramento de IP).
    - Logs do Traefik limpos, sem erros de API.
## 2025-12-31
**Status:** ✅ Sucesso (Traefik & Ingress)

**Foco:** Implementação do Proxy Reverso (Traefik) e Compatibilidade Docker API

- **Desafio (Dependency Hell):**
    - O Docker Engine no **Debian 13 (Trixie)** exige API mínima `1.44`.
    - O **Traefik v3** tenta negociar versões antigas (`1.24`) por padrão e falha em ambientes *bleeding edge*.
    - Tentativas de forçar a versão via flags (`--providers.docker.apiVersion`) ou variáveis (`DOCKER_API_VERSION`) no Traefik v3 falharam silenciosamente devido a mudanças recentes na lib interna.
- **Solução (Downgrade Tático):**
    - Revertido para **Traefik v2.11** (LTS).
    - Injetada variável de ambiente `DOCKER_API_VERSION=1.45` diretamente no container.
    - Isso forçou o cliente Docker interno do Traefik a falar a língua do Debian 13 sem negociação.
- **Validação:**
    - Acesso a `https://whoami.home` confirmado.
    - Redirecionamento HTTP -> HTTPS (80 -> 443) ativo.
    - **Header X-Real-IP:** O container recebe o IP real do cliente (`10.10.20.x`), confirmando que o roteamento Inter-VLAN está transparente.
- **Observação:**
    - Atualizar assim que possível para a versão mais recente (v2.11 ends Feb 01, 2026).
## 2025-12-30
**Status:** ✅ Sucesso (DNS & Privacy)

**Foco:** Implementação do AdGuard Home e Gestão de DNS
- **Infraestrutura DNS (LXC Container):**
    - Criado Container LXC `101 (AdGuard-Primary)` baseado em Alpine Linux (3.23) na VLAN 30.
    - **Specs:** 1 Core, 256MB RAM, IP Estático `10.10.30.5`.
    - **Software:** AdGuard Home instalado via script oficial.
        - `curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v`, disponível [aqui](https://github.com/AdguardTeam/AdGuardHome
).
- **Configuração do Serviço (AdGuard):**
    - **Upstreams:** Configurados servidores DNS-over-HTTPS (Cloudflare/Quad9) para garantir privacidade e evitar interceptação de porta 53 pelo ISP.
    - **Reverse DNS:** Apontado para o OPNsense (`10.10.30.1`) para resolução correta de hostnames locais nos logs.
- **Integração de Rede (OPNsense DHCP):**
    - Alterado o servidor DNS entregue via DHCP para as VLANs **TRUSTED (20)** e **IOT (50)**:
        - **De:** `1.1.1.1` e `8.8.8.8` (Externos (Cloudflare e Google, respectivamente).
        - **Para:** `10.10.30.5` (Local (AdGuard)).
    - **Política de Resiliência:** A VLAN **SERVER (30)** teve seu DNS mantido em `1.1.1.1` para evitar dependência cíclica (o DockerHost não deve depender de um container vizinho para resolver nomes durante o boot).
- **Validação:**
    - Cliente Arch Linux (VLAN 20) renovou DHCP e confirmou recebimento do DNS `10.10.30.5` via `/etc/resolv.conf`.
    - Dashboard do AdGuard registrou queries vindas da rede TRUSTED e bloqueios ativos.
    - O mesmo foi realizado com a VLAN 50.
- Documentação do repo melhor documentada e formatada.
- Repo aberto.
## 2025-12-29
**Status:** ✅ Sucesso (Docker & Hardening)

**Foco:** Configuração do DockerHost e Ajuste de Firewall

- **Hardening SSH:**
    - Chaves Ed25519 copiadas do Arch Linux para o DockerHost.
    - **Configuração de Segurança:** Editado `/etc/ssh/sshd_config` para:
        * `PermitRootLogin no` (Bloqueio total de login direto como root via SSH).
        * `PasswordAuthentication no` (Autenticação por senha desativada; apenas chaves SSH).
        * `PubkeyAuthentication yes` (Autenticação por chave pública habilitada).
        * `ChallengeResponseAuthentication no` (Desativa métodos interativos/legados de autenticação).
        * `UsePAM yes` (Mantém PAM ativo para controle de sessão e políticas do sistema).
    - **Validação:** Login verificado com sucesso via chave; tentativa de login por senha rejeitada como esperado.

- **Instalação do Docker:**
    - Utilizado repositório oficial (método compatível com Debian Trixie/Bookworm).
    - Engine e Plugin Compose (v5.0.0) instalados.
    - Usuário adicionado ao grupo `docker` para execução sem root/sudo.
    - **Teste de Sanidade:** `docker run hello-world` executado com sucesso (Pull da imagem via WAN OK, Execução OK).

- **Incidente de Conectividade (Firewall):**
    - *Sintoma:* O Arch Linux (VLAN 20) não conseguia pingar ou conectar via SSH no DockerHost (VLAN 30), resultando em Timeout.
    - *Causa Raiz:* Esquecimento da política de "Default Deny". Embora a VLAN 30 tivesse permissão de saída (para internet), a VLAN 20 não tinha permissão explícita de **entrada/passagem** para a VLAN 30.
    - *Solução:* Criada regra de Firewall na interface **TRUSTED**:
        - **Action:** Pass
        - **Source:** TRUSTED net
        - **Destination:** Any (ou SERVER net)
        - **Justificativa:** Permite que dispositivos de gerenciamento acessem os servidores.
        - O mesmo foi feito com a VLAN 50 (IOT).
## 2025-12-28
**Status:** ⚠️ Resgate de Rede (Driver Migration)

**Foco:** Recuperação das VLANs após mudança para VirtIO

- **O Incidente:**
    - Ao verificar a VM `DockerHost`, notei que ela não pegava IP (estava com APIPA `169.254.x.x`).
    - No OPNsense, as interfaces **TRUSTED**, **SERVER** e **IOT** haviam desaparecido do painel de controle, restando apenas LAN e WAN.
- **Diagnóstico:**
    - A mudança do driver de rede da VM OPNsense (de `e1000` para `VirtIO`) alterou a nomenclatura das interfaces no BSD (de `em0` para `vtnet0/1`).
    - Isso quebrou a associação "Parent Interface" das VLANs, tornando-as órfãs e desativadas.
    - Identifiquei via MAC Address (`04:FD`) que a interface `vtnet1` (atualmente WAN) era, na verdade, a porta física configurada com Trunks no Proxmox.
- **Solução:**
    1. **Reparenting:** Reconfigurei as VLANs 20, 30 e 50 para usarem a interface correta (`vtnet1`) como pai.
    2. **Re-assignment:** Re-adicionei as interfaces lógicas que haviam sumido.
    3. **Re-IP:** Restaurei os IPs Estáticos (`10.10.x.1`) e serviços DHCP que foram limpos durante a falha.
- **Resultado:** A VM DockerHost obteve o IP `10.10.30.102` imediatamente após o fix.
## 2025-12-27
**Status:** ✅ Sucesso

**Foco:** Provisionamento do DockerHost e Segmentação VLAN 30

- **Infraestrutura de Rede (VLAN 30 - SERVER):**
    - Configurada interface lógica no OPNsense (`10.10.30.1/24`) com DHCP ativado (`.100` a `.200`).
    - Validado isolamento: `ping` da VLAN 20 (Trusted) para 50 (IoT) falha como esperado (Bloqueio padrão).
    - Regras de Firewall: Criada regra temporária "Pass All" na VLAN 30 para permitir instalação de pacotes.
- **Computação (VM DockerHost):**
    - Criada VM ID `105` (Debian 13 Minimal (somente com SSH Server e Standard system utilities)).
    - **Specs:** 2 vCores (Host), 8GB RAM (Static), 32GB Disk (VirtIO Block).
    - **Rede:** Interface VirtIO com **Tag 30** definida no Proxmox.
    - **Validação:**
        - VM obteve IP `10.10.30.x` automaticamente.
        - Conectividade externa (WAN) funcionando via NAT Híbrido.
        - Acesso SSH verificado a partir da VLAN 20 (Trusted).
## 2025-12-26
**Status:** ✅ Sucesso Crítico (Rede Funcional)

**Foco:** Troubleshooting de VLANs, Switch e Roteamento OPNsense

- **O Incidente:** O DHCP não chegava aos clientes via Wi-Fi (VLANs 20/50) e, quando chegava (após fix), não havia navegação.
- **Diagnóstico e Soluções (Post-Mortem):**
    1. **Proxmox Bridge Dropping Tags:** A bridge `vmbr0` (VLAN Aware) estava descartando pacotes taggeados (20, 50) antes de entregá-los à VM.
        - *Correção:* Adicionado `bridge-vids 2-4094` em `/etc/network/interfaces` no Host.
        - *Correção:* Adicionado `trunks=20;50` na configuração da interface de rede da VM (`/etc/pve/qemu-server/100.conf`).
    2. **Conflito de Roteamento (Routing Loop):** A interface LAN (`192.168.0.250/24`) e WAN (`192.168.0.50/24`) estavam na mesma sub-rede. O kernel do OPNsense entrava em conflito de rota ao tentar responder a pacotes de outras VLANs, causando erro *"Provide a valid source address"* no Ping.
        - *Solução Definitiva:* Alterado IP da LAN para `192.168.99.1/24` para isolar as redes.
    3. **Hardware Offloading (VirtIO):** Pacotes DHCP chegavam corrompidos/descartados.
        - *Ajuste:* Desativado Hardware CRC, TSO e LRO nas configurações do OPNsense.
    4. **Firewall Block:** VLANs novas vêm com "Default Deny".
        - *Ajuste:* Criadas regras de "Pass All" e configurado Outbound NAT Híbrido.
## 2025-12-25
**Status:** 🔄 Troca de Hardware

**Foco:** Aquisição de Storage para Bitcoin Node

- **Problema Logístico:** O SSD SanDisk (comprado em 14/12) entrou em estado de atraso indefinido no Mercado Livre ("Em preparação" por 10 dias). Compra cancelada para evitar parada no projeto.
- **Revisão Técnica:** Aproveitei o incidente para reavaliar a especificação. Identifiquei que o SanDisk Plus é **DRAM-less**. Para um Full Node Bitcoin, isso seria catastrófico durante o IBD (Initial Block Download), pois o esgotamento do cache SLC derrubaria a velocidade de escrita drasticamente.
- **Decisão:** Adquirido **Samsung 870 EVO 2TB** (Envio Full).
    - Embora o custo seja marginalmente maior, ele possui **2GB de Cache LPDDR4** e controlador MKX. Isso garante que a sincronização da blockchain ocorra na velocidade máxima da interface SATA, economizando dias de espera futura.
    - A placa de rede HP NC364T (incompatível) devolvida também serviu para abater a diferença de custo.
## 2025-12-24
**Status:** ⚠️ Resgate de Rede (Rollback)

**Foco:** Recuperação de Acesso e Simplificação de Rede

- **O Incidente:**
    - Após o sucesso inicial com o Dropbear, tentamos migrar para a topologia "Router-on-a-Stick" configurando VLANs (10, 20, 90) no OPNsense e no Switch.
    - **Resultado:** Perda total de acesso (Lockout). O Dropbear parou de responder e o Proxmox ficou inacessível.
- **Diagnóstico (A Causa Raiz):**
    1. **Hardcoding no Boot:** O arquivo `/etc/initramfs-tools/initramfs.conf` continha uma linha forçando IP Estático (`IP:10.10.10.1...`).
    2. **Desalinhamento:** O Switch foi configurado para esperar VLANs, mas o servidor bootava forçando um IP fora da sub-rede e sem tagging, causando falha de comunicação.
- **A Solução (O Resgate):**
    - **Physical Reset:** Reset físico do Switch TP-Link para configurações de fábrica (Rede Flat 192.168.0.x).
    - **Boot Config:** Editado `initramfs.conf` para remover o IP estático e definir `IP=dhcp`.
    - **Proxmox Config:** Editado `/etc/network/interfaces` para usar DHCP na `vmbr0`.
- **Lição Aprendida:**
    - **NUNCA** definir IPs estáticos no `initramfs` em ambiente de Homelab. Usar `IP=dhcp` e controlar a fixação de IP via reserva no Roteador (DHCP Static Lease).
    - O Dropbear (Desbloqueio) deve permanecer sempre na VLAN Nativa/Untagged (Rede "Burra") para garantir acesso de emergência independente do estado do OPNsense.
## 2025-12-22
**Status:** ✅ Sucesso Total

**Foco:** Otimização de Hardware e Router-on-a-Stick

- **Decisão Técnica:** A placa HP Quad-Port foi removida. O custo de complexidade de driver e energia não justificava o uso, dado que o switch TP-Link gerencia VLANs com perfeição.
- **Troubleshooting Dropbear:** Após a remoção da placa HP, o nome da interface mudou de `enp8s0` para `enp4s0`. Isso quebrou o desbloqueio remoto inicial.
    - *Correção:* Atualizei o `initramfs.conf` com `DEVICE=enp4s0` e fixei a porta `2222`. O teste de `cryptroot-unlock` via SSH no notebook Arch funcionou após limpar o `known_hosts`.
- **OPNsense:** WAN configurada com sucesso na VLAN 90. O IP foi obtido via DHCP do modem em modo DMZ.
## 2025-12-21
**Status:** ✅ Sucesso

**Foco:** Criptografia (FDE), Swap e Desbloqueio Remoto

- **LUKS:** Realizei a conversão pós-instalação do Proxmox para **LUKS2** (Full Disk Encryption) seguindo o guia manual.
- **Swap:** Configurei um **ZFS Swap de 16GB** para evitar travamentos por exaustão de memória (OOM), já que o ZFS sem swap pode entrar em deadlock.
- **Dropbear:** Configurei o servidor SSH leve (Dropbear) no initramfs.
    - **Teste:** Reiniciei o servidor sem monitor. Conectei via SSH na porta temporária, digitei a senha do disco e o boot do Proxmox prosseguiu corretamente.

## 2025-12-20
**Status:** ✅ Sucesso

**Foco:** Dry Run (Instalação e Rede)

- **Instalação Base:** Instalei o Proxmox VE 9.1 para validar a detecção de hardware.
- **Rede:**
    - A interface Onboard foi identificada como `eno1` (Driver `r8169`).
    - A placa HP Quad-Port foi identificada corretamente (Driver `e1000e`).
    - **Latência:** Teste de ping direto registrou `0.2ms`.
- **Armazenamento:** O **ZFS Mirror (RAID 1)** foi montado e ativado no `rpool` com os dois NVMe Kingston.
- **Troubleshooting:** Tive dificuldade inicial para pingar o servidor (10.10.10.x) a partir do meu Arch Linux.
    - *Solução:* Era necessário ajustar as regras de entrada/saída no firewall do cliente (Arch), pois não há roteador intermediando a conexão física direta neste estágio.

## 2025-12-19
**Status:** ✅ Sucesso

**Foco:** Hardware Burn-in e BIOS

- **Validação de Memória:** Executei o **MemTest86 V11.5** por 6 horas e 17 minutos.
    - **Resultado:** 48/48 testes completados com **0 Erros**.
    - *Telemetria:* XMP validado a 3192 MT/s. A temperatura máxima da CPU ficou em 48°C, validando a instalação do cooler AK400.
![Evidência do MemTest86](https://github.com/fajremvp/homelab/blob/main/docs/assets/benchmarks/MemTest86.jpeg)
- **Configuração da BIOS:** Apliquei as configurações críticas na Gigabyte B760M.
