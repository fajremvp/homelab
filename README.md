# 🏠 Homelab

Repositório central de "Infrastructure as Code" (IaC) e documentação do meu laboratório doméstico.
Focado em aprendizado, soberania de dados e segurança.

**Status:** 🚧 Em Construção

---

## 📂 Estrutura do Repositório

```text
homelab/
├── .github/                # Workflows de CI (GitHub Actions) para validar código.
├── .gitignore              # Arquivos ignorados (Segurança: impede vazar senhas/keys).
├── CHANGELOG.md            # Histórico executivo de mudanças e versões do lab.
├── README.md               # Este arquivo
│
├── docs/                   # A "Wiki" do Lab (Documentação Viva)
│   ├── JOURNAL.md          # Diário de Bordo (Erros, tentativas e aprendizados diários).
│   ├── assets/             # Evidências, prints de benchmarks e diagramas.
│   ├── architecture/       # Decisões de Design (VLANs, DNS, Escolha de SO).
│   ├── hardware/           # Inventário Físico (Specs do Servidor, Pi, Nobreak).
│   ├── security/           # Políticas (Modelo de Ameaça, Hardening, IAM).
│   ├── services/           # Detalhes das Aplicações (Bitcoin, OPNsense, Docker).
│   ├── runbooks/           # Manuais de "Como Fazer" (Cold Boot, Disaster Recovery).
│   └── lab/                # Ambientes efêmeros (Pentest, Testes isolados).
│
├── provisioning/           # Infraestrutura (Criação de Recursos)
│   ├── proxmox-host/       # Configs manuais do Host (Rede, Boot, Criptografia).
│   │   ├── cmdline.conf    # Parâmetros de Kernel (IOMMU, IP Estático).
│   │   ├── crypttab.conf   # Otimização de performance NVMe + LUKS.
│   │   ├── interfaces.conf # Configuração das Bridges e VLANs.
│   │   └── hook-scripts/   # Scripts de systemd/udev (Fixação de MAC).
│   ├── terraform/          # Código para criar VMs/LXC automaticamente.
│   └── cloud/              # Recursos externos (Backblaze B2, DNS público).
│
├── configuration/          # Configuração (Instalação de Software)
│   ├── inventory/          # Lista de IPs e Grupos para o Ansible.
│   ├── playbooks/          # Automação (Instalar Docker, Endurecer SSH).
│   └── roles/              # Funções modulares e reutilizáveis do Ansible.
│
├── kubernetes/             # O Cluster (Talos Linux)
│   ├── talos-config/       # YAMLs declarativos do Sistema Operacional.
│   └── manifests/          # Aplicações K8s (ArgoCD, Namespaces, Storage).
│
└── scripts/                # Automação e Utilitários (Bash)
    ├── backup-bitcoin.sh        # Snapshot atômico da wallet (sem corromper).
    ├── nut-shutdown.sh          # Lógica de desligamento por bateria fraca.
    └── update-initramfs-hook.sh # Automação pós-update de Kernel.
```