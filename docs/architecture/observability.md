# Estratégia de Observabilidade

## Filosofia

Começar pelo essencial.
Estabilidade, previsibilidade e soberania total dos dados têm prioridade sobre complexidade e modismos.

Nada de SaaS externo. Nada de stack pesada sem necessidade.

---

## Stack Adotada (LGTM)

- **Visualização:** Grafana
- **Métricas:** Prometheus
- **Logs:** Loki
- **Coleta de Logs:** Grafana Alloy

---

## Arquitetura de Coleta

| Camada | Ferramenta | Tipo | O que monitora | Justificativa técnica |
|------|-----------|------|---------------|----------------------|
| Hardware / OS | Node Exporter | Serviço systemd | CPU, RAM, disco, IO, temperatura | Rodar nativo garante acesso real ao kernel e evita distorções de containers |
| Containers | cAdvisor | Container | Uso de CPU/RAM/IO por container | Node Exporter não detalha consumo individual |
| Logs | Grafana Alloy | Container | Journald e logs Docker via arquivo | Leitura direta de disco é mais rápida e estável que API Docker |
| Rede (hardware) | SNMP Exporter | Container | Switch e AP | Única opção para dispositivos proprietários |

---

## Alertas

- **Gerenciamento:** Alertmanager
- **Canal Crítico:** ntfy (self-hosted)
- **Canal Informativo:** e-mail (Stalwart)

---

## Roadmap de Implementação

### Fase 1 – Núcleo de Observabilidade (ATUAL)

**Objetivo:** ter visibilidade total do DockerHost.

- Subir stack central:
  - Prometheus
  - Loki
  - Grafana
  - Alloy
  - Alertmanager
- Instalar `node_exporter` no DockerHost (fora do Docker)
- Coletar:
  - Métricas do host
  - Métricas de containers
  - Logs Docker
  - Logs do sistema (SSH, sudo)

**Resultado:** detectar falhas antes de downtime.

---

### Fase 2 – Expansão de Agentes

**Objetivo:** monitorar todas as VMs e nós Linux.

- Instalar `node_exporter` via Ansible em:
  - Proxmox Host
  - VM Vault
  - LXCs
  - Raspberry Pi
- Adicionar targets no Prometheus

**Resultado:** saúde completa da infraestrutura lógica.

---

### Fase 3 – Infraestrutura Física e Defesa

**Objetivo:** visibilidade de rede e segurança.

- SNMP:
  - Switch
  - Access Point
- CrowdSec:
  - Métricas de ataques e banimentos
- UPS:
  - NUT + exporter

---

### Fase 4 – Refinamento

- Dashboards específicos (ZFS, backups, latência)
- Alertas ajustados para evitar ruído
