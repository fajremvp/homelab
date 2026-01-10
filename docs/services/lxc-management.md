* **Terraform / Ansible / Restic:** `[LXC Alpine - Gerenciamento]`
    * **Justificativa:** Centraliza as ferramentas de automação e IaC.
        * **Ansible:** Configura o software e aplica hardening em todos os nós. Atua como "Torre de Controle".
        * **Restic:** O binário é instalado em todos os hosts, mas o Management armazena os Playbooks que definem a política de backup e as chaves (em variáveis protegidas, não no Git). O Management também realiza backup de si mesmo (`/opt/homelab`).
        * O **Terraform** será usado para *provisionar* a infraestrutura (VMs, LXCs) de forma declarativa.
