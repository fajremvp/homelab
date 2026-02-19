# Estratégia de Observabilidade

## Filosofia
Começar pelo essencial. Estabilidade, previsibilidade e soberania total dos dados têm prioridade sobre complexidade.
Adoção de padrões de arquitetura corporativa (Enterprise Patterns), porém adaptados para escala de Homelab (Trust-on-Device).

---

## Stack Adotada (LGM)
*Acrônimo ajustado: Tracing (Tempo), traces só fazem sentido com apps próprios ou microserviços complexos (agora é peso morto)*

- **Visualização:** Grafana
- **Métricas:** Prometheus
- **Logs:** Loki
- **Coleta:** Grafana Alloy

---

## Arquitetura e Fluxo de Dados

| Camada | Componente | Método de Coleta | Justificativa Técnica |
|--------|------------|------------------|-----------------------|
| **Host Logs** | Alloy | Leitura direta (`/var/log/journal`) | Acesso de baixo nível ao kernel e systemd. |
| **Container Logs** | Alloy | Leitura de arquivo (`json-file`) | Evita gargalo na API do Docker Socket em cargas altas. |
| **Host Metrics** | Node Exporter | Serviço Systemd (Nativo) | Isolamento de falhas: se o Docker cair, ainda temos métricas do OS. |
| **Container Metrics** | cAdvisor | Container Privilegiado | Granularidade por cgroup que o Node Exporter não oferece. |
| **Ingress** | Traefik | TLS Termination | Centraliza SSL e protege dashboards (Grafana) atrás do Authentik. |
| **Uptime (Externo)** | Heartbeat (Curl) | Push para Healthchecks.io | Garante notificação mesmo em caso de falha total de energia/internet (Dead Man's Switch). |

---

## Estratégia de Dashboards (GitOps)

Para garantir a recuperabilidade e auditoria, os painéis do Grafana seguem o modelo **Dashboard as Code**.

1.  **Imutabilidade:** Dashboards não são criados ou salvos no banco de dados interno do Grafana via interface web.
2.  **Fonte da Verdade:** Arquivos JSON armazenados em `configuration/dockerhost/monitoring/grafana/dashboards/`.
3.  **Provisionamento:** O Grafana é configurado para ler esta pasta no boot. Alterações manuais na UI são perdidas ao reiniciar o container, forçando o operador a comitar a mudança no Git.

**Estrutura de Arquivos:**
- `provisioning/dashboards/main.yml`: Instrui o Grafana a carregar os arquivos.
- `dashboards/*.json`: O código fonte dos painéis (Node Exporter, Traefik, cAdvisor).

---

## 🛡️ Threat Model & Limites de Confiança (Fase 1)

Esta implementação assume um modelo de ameaça específico para ambiente doméstico controlado.

1.  **PKI Local (Mkcert):**
    * **Modelo:** Trust-on-device (Confiança manual no dispositivo).
    * **Limitação:** Não há CRL (Lista de Revogação) ou OCSP. Se a chave da CA vazar, a revogação exige remoção manual da CA em todos os dispositivos clientes.
    * **Proteção MITM:** Efetiva contra atacantes na rede local, *desde que* a CA não esteja comprometida.
    * Não indicado para ambientes multi-tenant ou expostos à internet.

2.  **Alertas:**
    * A infraestrutura de roteamento (Alertmanager -> Ntfy) está funcional.
    * **Lacuna Atual:** Nenhuma regra de alerta (Recording/Alerting Rules) foi definida no Prometheus. O sistema é observável, mas reativo.

3.  **Segurança de Segredos:**
    * Chaves TLS privadas armazenadas em disco (`/opt/services/traefik/certs`). Proteção baseada em permissões de arquivo do Linux (DAC).
    * Não há HSM nem TPM na Fase 1.

---

## Roadmap de Implementação

### Fase 1 – Núcleo de Observabilidade (DockerHost) [CONCLUÍDO]
**Objetivo:** Visibilidade total do servidor de containers e infraestrutura de suporte.

- [x] **Stack Central:** Prometheus, Loki, Grafana, Alloy, Alertmanager.
- [x] **Log Strategy:** Migração de Docker para driver `json-file`.
- [x] **Segurança:** Autenticação via Authentik e TLS via Mkcert (Wildcard estático).
- [x] **Notificação:** Ntfy self-hosted com validação SSL no Android.
- [x] **Backup:** Integração com Restic.

### Fase 2 – Expansão de Agentes [CONCLUÍDO]
**Objetivo:** Monitoramento de nós satélites (Virtualização e Segurança).

- [x] **Proxmox (Host):** Node Exporter (Métricas de OS via apt) + PVE Exporter (Métricas de Cluster via API).
- [ ] **Proxmox (Logs):** Promtail/Alloy (Coleta de syslogs do Hypervisor) - *Adiado para manter o host limpo*.
- [x] **Vault (VM):** Node Exporter (Binário standalone) com firewall restrito (Allow 9100 from DockerHost only).
- [x] **Raspberry Pi (Management):** Monitoramento de recursos (CPU/RAM/Temp) via Node Exporter.
- [x] **Alertas:** Pipeline de alertas críticos (Instance Down, Resource Exhaustion) via Alertmanager -> Ntfy.
- [x] **OrangeShadow (VM):** Node Exporter.

### Fase 3 – Infraestrutura Física
**Objetivo:** Visibilidade de rede e energia.

- [x] **Disponibilidade Global:** Dead Man's Switch (Healthchecks.io) monitorando o DockerHost.
- [ ] **Switch/AP:** Coleta via SNMP Exporter.
- [ ] **Energia:** Monitoramento de UPS (NUT Exporter).
- [X] **Segurança de Rede:** CrowdSec (Logs de firewall e banimentos).

### Fase 4 – Refinamento e Inteligência
**Objetivo:** Transformar dados em alertas acionáveis.

- [ ] **Alerting Rules:** Definição de limiares (Disco > 90%, Alta Temperatura, Vault Sealed).
- [X] **Dashboards:** Criação de visão unificada ("Single Pane of Glass").
- [ ] **Watchdog:** Monitoramento de disponibilidade da própria stack de monitoramento (Dead Man's Switch).
