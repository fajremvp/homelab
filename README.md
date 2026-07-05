# 🏠 Homelab

Repositório central de "Infrastructure as Code" (IaC) e documentação do meu homelab.
Focado em aprendizado, soberania de dados e segurança.

---

**Diagrama/Mapa atual:**

![Homelab Diagram/Map](docs/diagram/diagram.png)

---

## 📂 Estrutura do Repositório

```text
homelab/
├── .gitignore              # Regras de exclusão (Segurança/Dados sensíveis)
├── .gitleaks.toml          # Allowlist para metadados SOPS (evita falso-positivo no Gitleaks)
├── .ansible-lint           # Exclui *.sops.yaml da regra yaml[line-length]
├── .sops.yaml              # Regras de criptografia e chaves age destinatárias
├── .pre-commit-config.yaml # Regras de CI/CD (Linting & Security)
├── ansible.cfg             # Configuração central do Ansible
├── requirements.yml        # Pin da collection community.sops
├── CHANGELOG.md            # Histórico formal de mudanças e versões
├── LICENSE                 # MIT License
├── README.md               # Este arquivo
│
├── configuration/          # Gerenciamento de Configuração (Ansible & GitOps)
│   ├── proxmox/            # Configurações do Host Virtualizador (ex: NUT Secondary)
│   ├── rpi/                # Configurações do Edge Node (ex: NUT Primary e Scripts)
│   ├── orangeshadow/       # Configurações da VM OrangeShadow (Bitcoin e Monero)
│   ├── dockerhost/         # Stacks de Microsserviços (Docker Compose)
│   │   ├── auth/           # Gestão de Identidade e Acesso (Authentik)
│   │   ├── monitoring/     # Observabilidade PLG (Prometheus, Loki, Grafana, Alloy)
│   │   ├── security/       # Camada de Defesa (CrowdSec IDS/IPS)
│   │   └── services/       # Aplicações e Infraestrutura (Traefik, VPNs, Vaultwarden, Nostr)
│   ├── inventory/          # Inventário de Hosts (hosts.ini) e segredos cifrados (SOPs)
│   │   ├── hosts.ini       # Definição dos hosts e grupos
│   │   └── group_vars/     # Segredos cifrados (SOPS) por grupo de hosts
│   ├── playbooks/          # Automação (Hardening, Backups, Setup de Stacks)
│   └── roles/              # Roles reutilizáveis do Ansible
│
├── diagram/                # Topologia Visual
│   ├── diagram.drawio      # Fonte editável (Diagrama como Código)
│   └── diagram.png         # Renderização atual da arquitetura
│
├── docs/                   # Base de Conhecimento (Knowledge Base)
│   ├── architecture/       # Decisões de Design (Network Topology, Observability)
│   ├── assets/             # Evidências e Benchmarks (MemTest, Logs)
│   ├── hardware/           # Inventário Físico, BIOS e BOM (Bill of Materials)
│   ├── JOURNAL.md          # Diário de Engenharia (Lessons Learned)
│   ├── kubernetes/         # Manifestos e configs para o cluster k8s (Talos)
│   ├── lab/                # Ambientes de teste e Pentest
│   ├── runbooks/           # Procedimentos Operacionais (Disaster Recovery, Cold Boot)
│   ├── security/           # Governança (Threat Model, Zero Trust, Key Management)
│   └── services/           # Documentação Técnica dos Serviços (VMs e LXCs)
│
├── provisioning/           # Infraestrutura como Código (IaC)
│   ├── proxmox-host/       # Configs Críticas (Network Interfaces, LUKS Encryption)
│   └── tailscale/          # ACLs de Rede Mesh (HuJSON)
│
└── scripts/                    # Automações operacionais e ferramentas CLI
    ├── check-sops-encrypted.sh # Hook de pre-commit: bloqueia texto plano em group_vars/
    └── dr-checkpoint.sh        # Script de pull manual para Disaster Recovery (Air-Gapped)
```
