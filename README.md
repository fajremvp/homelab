# 🏠 Homelab

Repositório central de "Infrastructure as Code" (IaC) e documentação do meu homelab.
Focado em aprendizado, soberania de dados e segurança.

---

**Diagrama/Mapa atual:**

![Homelab Diagram/Map](diagram/diagram.png)

---

## 📂 Estrutura do Repositório

```text
homelab/
├── .gitignore              # Regras de exclusão (Segurança/Dados sensíveis).
├── .pre-commit-config.yaml # Regras de CI/CD (Linting & Security).
├── ansible.cfg             # Configuração central do Ansible.
├── CHANGELOG.md            # Histórico formal de mudanças e versões.
├── LICENSE                 # MIT License
├── README.md               # Este arquivo.
│
├── configuration/          # Gerenciamento de Configuração (Ansible & GitOps).
│   ├── proxmox/            # Configurações do Host Virtualizador (ex: NUT Secondary).
│   ├── rpi/                # Configurações do Edge Node (ex: NUT Primary e Scripts).
│   ├── dockerhost/         # Stacks de Microsserviços (Docker Compose).
│   │   ├── auth/           # Gestão de Identidade e Acesso (Authentik).
│   │   ├── monitoring/     # Observabilidade PLG (Prometheus, Loki, Grafana, Alloy).
│   │   ├── security/       # Camada de Defesa (CrowdSec IDS/IPS).
│   │   └── services/       # Aplicações e Infraestrutura (Traefik, VPNs, Vaultwarden, Nostr).
│   ├── inventory/          # Inventário de Hosts (hosts.ini).
│   ├── playbooks/          # Automação (Hardening, Backups, Setup de Stacks).
│   ├── roles/              # Roles reutilizáveis do Ansible.
│   └── vault/              # Políticas ACL (HCL) e configurações do HashiCorp Vault.
│
├── diagram/                # Topologia Visual.
│   ├── diagram.drawio      # Fonte editável (Diagrama como Código).
│   └── diagram.png         # Renderização atual da arquitetura.
│
├── docs/                   # Base de Conhecimento (Knowledge Base).
│   ├── architecture/       # Decisões de Design (Network Topology, Observability).
│   ├── assets/             # Evidências e Benchmarks (MemTest, Logs).
│   ├── hardware/           # Inventário Físico, BIOS e BOM (Bill of Materials).
│   ├── JOURNAL.md          # Diário de Engenharia (Lessons Learned).
│   ├── kubernetes/         # Manifestos e configs para o cluster k8s (Talos).
│   ├── lab/                # Ambientes de teste e Pentest.
│   ├── runbooks/           # Procedimentos Operacionais (Disaster Recovery, Cold Boot).
│   ├── security/           # Governança (Threat Model, Zero Trust, Key Management).
│   └── services/           # Documentação Técnica dos Serviços (VMs e LXCs).
│
└── provisioning/           # Infraestrutura como Código (IaC).
    ├── cloud/              # Provisionamento de recursos em nuvem.
    ├── proxmox-host/       # Configs Críticas (Network Interfaces, LUKS Encryption).
    ├── tailscale/          # ACLs de Rede Mesh (HuJSON).
    └── terraform/          # Provisionamento de VMs/LXCs.
```
