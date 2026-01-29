# Diário de Bordo

Este arquivo documenta a jornada, erros, aprendizados e decisões diárias.
Para mudanças estruturais formais, veja o [CHANGELOG](../CHANGELOG.md).

---
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
