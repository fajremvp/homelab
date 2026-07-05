* **Terraform / Ansible / Restic:** `[LXC Alpine - Gerenciamento]`
    * **Justificativa:** Centraliza as ferramentas de automação e IaC.
        * **Ansible:** Configura o software e aplica hardening em todos os nós. Atua como "Torre de Controle".
        * **Restic:** O binário é instalado em todos os hosts, mas o Management armazena os Playbooks que definem a política de backup e as chaves (em variáveis protegidas, não no Git). O Management também realiza backup de si mesmo (`/opt/homelab`).
        * O **Terraform** será usado para *provisionar* a infraestrutura (VMs, LXCs) de forma declarativa.
        * **SOPS/age:** Único host que armazena a chave privada age primária (`/root/.config/sops/age/keys.txt`, `0600`, root-only). É o único ponto da infraestrutura capaz de decifrar `group_vars/*.sops.yaml`. Coberto pelo backup Restic e pelo `dr-checkpoint.sh` (ver `docs/security/key-management.md`).
