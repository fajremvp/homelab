# 🏠 Homelab

Repositório central de "Infrastructure as Code" (IaC) e documentação do meu homelab.
Focado em aprendizado, soberania de dados e segurança.

**Diagrama/Mapa:**
![Homelab Diagram/Map](diagram/diagram.png)

---

## 📂 Estrutura do Repositório

```text
homelab/
├── ansible.cfg             # Configuração central do Ansible.
├── CHANGELOG.md            # Histórico executivo de mudanças e versões.
├── LICENSE
├── README.md               # Este arquivo.
│
├── configuration/          # Gerenciamento de Configuração (Ansible & GitOps).
│   ├── dockerhost/         # Stacks de Serviços (Docker Compose & Systemd).
│   │   ├── authentik/      # Identity Provider & SSO.
│   │   ├── monitoring/     # Stack LGM (Loki, Grafana, Prometheus, Alloy).
│   │   ├── security/       # CrowdSec (IDS/IPS e Bouncers).
│   │   ├── traefik/        # Ingress Controller & Certificados.
│   │   └── vaultwarden/    # Gerenciador de Senhas.
│   ├── inventory/          # Inventário de Hosts e Grupos (hosts.ini).
│   ├── playbooks/          # Automação (Hardening, Backups, Deploys).
│   └── vault/              # Políticas e configurações do HashiCorp Vault.
│
├── docs/                   # A "Wiki" do Lab (Documentação Viva).
│   ├── architecture/       # Decisões de Design (Rede, Energia, Observabilidade).
│   ├── hardware/           # Inventário Físico e configurações de BIOS.
│   ├── JOURNAL.md          # Diário de Bordo (Erros, tentativas e aprendizados).
│   ├── runbooks/           # Manuais de "Como Fazer" (Cold Boot, Disaster Recovery).
│   ├── security/           # Políticas (Modelo de Ameaça, Hardening, IAM).
│   └── services/           # Detalhes técnicos das Aplicações.
│
├── provisioning/           # Infraestrutura (Criação de Recursos).
│   ├── proxmox-host/       # Configs manuais do Host (Rede, Boot, Criptografia).
│   └── terraform/          # Código para criar VMs/LXC automaticamente.
│
├── kubernetes/             # O Cluster (Talos Linux) [Em Construção].
│
└── scripts/                # Automação e Utilitários (Bash).
    ├── backup-bitcoin.sh   # Snapshot atômico da wallet.
    └── nut-shutdown.sh     # Lógica de desligamento por bateria fraca.
```

---

## ✅ Todo List
