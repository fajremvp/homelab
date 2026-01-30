### Padronização de Sistemas Operacionais

* **Filosofia:** "Cattle, not Pets" (Gado, não animais de estimação). Prioridade para estabilidade na camada base (Host) e inovação na camada de aplicação.

| Categoria | SO Escolhido | Justificativa Técnica | Onde será usado |
| :--- | :--- | :--- | :--- |
| **Infraestrutura Crítica (VMs)** | **Debian Stable (Minimal)** | O "Padrão Ouro". Usa `glibc` (máxima compatibilidade com containers proprietários) e `systemd`. Estabilidade absoluta para serviços que não podem falhar. | DockerHost, Vault, Bitcoin Node. |
| **Micro-Serviços (LXCs)** | **Alpine Linux** | Eficiência extrema. Baseada em `musl` e `BusyBox`. Consumo de ~5MB RAM por container. Superfície de ataque mínima. | AdGuard, Management. |
| **Edge Management** | Raspberry Pi OS Lite (64) | Baseado no Debnian 13 (Trixie). Kernel otimizado para SoC Broadcom. Sem GUI (Headless) para maximizar recursos. | Raspberry Pi 4 (Nó de Gerenciamento). |
| **Kubernetes (Nodes)** | **Talos Linux** | SO imutável e minimalista. Sem SSH, sem Shell. Gerenciado 100% via API/YAML ("Infrastructure as Code" puro). Segurança máxima para o cluster. | Cluster Kubernetes (Control Plane e Workers). |
| **Pentest/Hacking** | **Kali Linux** | Padrão da indústria ofensiva. Toolset pré-configurado. | VM de Pentest (DMZ). |
