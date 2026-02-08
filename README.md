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
├── ansible.cfg             # Configuração central do Ansible.
├── CHANGELOG.md            # Histórico executivo de mudanças e versões.
├── LICENSE
├── README.md               # Este arquivo.
│
├── configuration/          # Gerenciamento de Configuração (Ansible & GitOps).
│   ├── dockerhost/         # Stacks de Microsserviços (Docker Compose).
│   │   ├── authentik/      # Identity Provider (SSO, OIDC) + Vault Integration.
│   │   ├── monitoring/     # Observabilidade PLG (Prometheus, Loki, Grafana, Alloy).
│   │   ├── security/       # Camada de Defesa (CrowdSec IDS/IPS).
│   │   ├── services/       # Aplicações Soberanas (Nostr Relay + Tor, Tailscale).
│   │   ├── traefik/        # Edge Router & Certificados (Ingress).
│   │   ├── vaultwarden/    # Gestão de Senhas (Self-hosted).
│   │   └── whoami/         # Debug & Connectivity Tests.
│   ├── inventory/          # Inventário de Hosts (hosts.ini).
│   ├── playbooks/          # Automação (Hardening, Backups, Setup de Stacks).
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
│   ├── runbooks/           # Procedimentos Operacionais (Disaster Recovery, Cold Boot).
│   ├── security/           # Governança (Threat Model, Zero Trust, Key Management).
│   └── services/           # Documentação Técnica dos Serviços (Bitcoin Node, LXCs).
│
├── provisioning/           # Infraestrutura como Código (IaC).
│   ├── proxmox-host/       # Configs Críticas (Network Interfaces, LUKS Encryption).
│   ├── tailscale/          # ACLs de Rede Mesh (HuJSON).
│   └── terraform/          # Provisionamento de VMs/LXCs (Em desenvolvimento).
│
└── LICENSE                 # MIT License.
```

