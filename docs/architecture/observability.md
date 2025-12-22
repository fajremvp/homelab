### 2.3. Estratégia de Observabilidade (The "All-Seeing Eye")

* **Filosofia:** "If it moves, measure it. If it logs, capture it." Soberania total dos dados de telemetria (sem SaaS externos). Foco no padrão moderno **OpenTelemetry**.
* **A Stack (LGTM):**
    * **Visualização:** `Grafana` (Dashboard único para tudo).
    * **Métricas:** `Prometheus` (Padrão de mercado para time-series).
    * **Logs:** `Loki` (Agregação eficiente, indexação apenas de metadados).
    * **Coletor Unificado:** `Grafana Alloy` (Substituto moderno do Promtail/Telegraf, compatível com OTel).

| Camada | Ferramenta de Coleta (Agente) | O que é monitorado | Destino |
| :--- | :--- | :--- | :--- |
| **Hardware/OS** | **Node Exporter** | CPU, RAM, Disco, IOPS, Temperatura. Instalado via Ansible em *todos* os hosts. | Prometheus |
| **Logs & Traces** | **Grafana Alloy** | Arquivos em `/var/log/*`, `journald` e Traces de aplicações. Substitui o antigo Promtail. | Loki / Tempo |
| **Docker** | **Cadvisor** | Consumo de recursos (CPU/RAM) isolado por container. | Prometheus |
| **Rede (SNMP)** | **SNMP Exporter** | Tráfego de portas do Switch e Roteador OPNsense (Interface WAN/LAN). | Prometheus |
| **Kubernetes** | **Kube-Prometheus-Stack** | Pacote completo (Operator) que já instala métricas de Pods, Nodes e Serviços. | Prometheus |
| **Energia (UPS)** | **NUT Exporter** | Carga da bateria, voltagem e tempo restante. | Prometheus |

* **Alerting (Ação):**
    * **Ferramenta:** `Alertmanager` (Prometheus) gerenciando a deduplicação e roteamento.
    * **Canal Crítico:** **ntfy (Self-hosted)**.
        * *Justificativa:* Notificações Push imediatas no Android/iOS sem depender de Big Tech. Simples (HTTP POST), permite envio de anexos (ex: log de erro) e ações rápidas ("Clique aqui para reiniciar container").
    * **Canal Informativo:** E-mail (Via Stalwart local).
    * **Regras Exemplo:** "Disco > 90%", "Temperatura > 80°C", "Falhas de SSH (CrowdSec) > 10/min".