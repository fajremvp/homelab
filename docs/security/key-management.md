# Gestão de Segredos (SOPS + age)

## Contexto Histórico

Este documento substitui o antigo `key-management.md` (removido em 2026-07-02 junto do decommission do HashiCorp Vault). A causa raiz da remoção do Vault está documentada no `JOURNAL.md` de 02/07/2026: o único uso real era AppRole estático para duas senhas, pagando o preço de uma VM dedicada, VLAN isolada e fricção de unseal manual pós-reboot. A migração para `vars_prompt` no Ansible foi assumida desde o início como uma solução transitória (ver nota de dívida técnica no `CHANGELOG.md` de 2026-07-02).

Esta migração (2026-07-04) fecha essa dívida técnica.

## Por que SOPS + age (e não Vault novamente)

### Comparativo das Alternativas Avaliadas

| Ferramenta / Abordagem | Criptografia | Fluxo de Revisão (Git/PR) | Dependência de Boot | Integração K8s (Futuro) | Veredito |
|---|---|---|---|---|---|
| **Ansible Vault** | Simétrica (AES-256 + senha mestre) | Arquivo inteiro vira um bloco cifrado; diffs praticamente inúteis. | Nenhuma. | Limitada. | Simples, porém prejudica auditoria e escalabilidade para GitOps. |
| **Secret Server (Vault/Infisical)** | Dinâmica via API | Excelente (segredos fora do Git). | Alta. O servidor precisa existir antes de toda a infraestrutura. | Excelente. | Rejeitado por adicionar complexidade desnecessária para poucos segredos estáticos. |
| **SOPS + age** | Assimétrica (age) | Excelente. Apenas os valores são cifrados, preservando diffs úteis. | Nenhuma. | Suporte nativo em FluxCD e ArgoCD. | Escolha adotada para este Homelab. |

- **Sem servidor/daemon:** SOPS decripta em memória do processo `ansible-playbook`. Não existe serviço para cair, nenhum unseal manual pós-reboot.
- **Sem dependência de nuvem:** ao contrário de SOPS+KMS (AWS/GCP), `age` é puramente local — alinhado ao princípio de Soberania Total de Dados.
- **Chave assimétrica:** a chave pública vai para o Git sem risco; só a privada é sensível, e ela nunca sai do LXC Management (exceto para a workstation NixOS, onde os arquivos são editados).
- **Auditável no `git diff`:** os *nomes* das variáveis permanecem legíveis; só os *valores* são cifrados. Isso preserva o modelo GitOps já usado no resto do repositório.
- **Compatível com GitOps desde o início:** embora o Homelab ainda utilize Ansible, a estrutura de segredos já é compatível com FluxCD/ArgoCD, evitando uma futura migração de formato durante a adoção do Kubernetes.

## Escopo da Migração

**Migrado para SOPS:**
- Todos os `vars_prompt` dos playbooks `configuration/playbooks/dockerhost/` (`auth.yml`, `core.yml`, `monitoring.yml`, `security.yml`, `services.yml`).
- Credenciais do Restic/Backblaze B2 (`configuration/playbooks/setup_backup.yml`), por serem reutilizáveis em qualquer VM/LXC futuro.

**Deliberadamente fora do escopo:**
- `tailscale_auth_key` do Raspberry Pi (`hardening_rpi.yml`) e as senhas do NUT (`configuration/rpi/nut/`, `configuration/proxmox/nut/`).
- **Motivo:** são segredos configurados uma única vez e nunca mais tocados. O RPi é um nó de borda descartável (Cattle, não Pet — ver `os-standardization.md`). O ganho de SOPS está em segredos que sofrem rotação/deploy repetido; aplicar aqui seria complexidade sem retorno.

## Arquitetura

```text
NixOS (edição)  --git push-->  GitHub  --git pull-->  LXC Management (execução)
      │                                                        │
      │  ~/.config/sops/age/keys.txt          /root/.config/sops/age/keys.txt
      │  (chave primária, uso manual)          (chave primária, uso automatizado)
```
Chave Age primária (~/.config/sops/age/keys.txt) (/root/.config/sops/age/keys.txt))

A chave privada **nunca** toca DockerHost, RPi, Proxmox ou OrangeShadow. Esses hosts só recebem os arquivos finais renderizados (`.env`, `/etc/restic-env.sh`) via `copy`/`template`, exatamente como já ocorria antes com `vars_prompt` — a única mudança é a *origem* do valor, não o destino.

## Localização das Chaves

| Chave | Onde vive | Função |
|---|---|---|
| Primária (privada) | NixOS + LXC Management | Edição + execução diária |
| Primária (pública) | `.sops.yaml` (Git) | Destinatário de criptografia |
| Emergência (privada) | Vaultwarden (Nota Segura) + HD air-gapped | Recuperação de desastre |
| Emergência (pública) | `.sops.yaml` (Git) | Destinatário secundário de criptografia |

## Estrutura de Arquivos de Segredo

| Arquivo | Escopo | Variáveis |
|---|---|---|
| `configuration/inventory/group_vars/dockerhost/secrets.sops.yaml` | Grupo `dockerhost` | `tailscale_authkey`, `authentik_secret_key`, `authentik_db_password`, `grafana_password`, `healthchecks_uuid`, `pve_password`, `ntfy_token`, `vaultwarden_admin_token`, `speedtest_app_key`, `miniflux_db_password`, `miniflux_admin_password` |
| `configuration/inventory/group_vars/all/secrets_backup.sops.yaml` | Todos os hosts | `b2_account_id`, `b2_account_key`, `restic_password`, `restic_repo_base` |

Optei por um único arquivo `secrets.sops.yaml` por host (em vez de segmentarpor serviço) porque sou operador único — não há necessidade de segregar acesso por equipe. Se este arquivo crescer excessivamente no futuro, a fragmentação por domínio (auth/monitoring/services) pode ser feita a qualquer momento sem custo de migração, já que `sops` opera por arquivo.

## Fluxo Operacional

**Adicionar/editar segredo:**
```bash
sops configuration/inventory/group_vars/dockerhost/secrets.sops.yaml
# edita em memória, salva já recriptografado
git add . && git commit -m "..." && git push
```

**Aplicar (no LXC Management):**
```bash
cd /opt/homelab && git pull
ansible-playbook configuration/playbooks/dockerhost/<playbook>.yml
```

**Validar sem aplicar:**
```bash
ansible-inventory --host 10.10.30.10 | grep <variavel>
```
**Rotação de chave (perda de laptop, suspeita de comprometimento):**
```bash
age-keygen -o admin-primary-new.key
# atualizar .sops.yaml com a nova public key, remover a antiga
find configuration/inventory/group_vars -name '*.sops.yaml' -exec sops updatekeys {} \;
# distribuir admin-primary-new.key só para o LXC Management
```

## Ferramental de Proteção

| Ferramenta | Função |
|---|---|
| `.sops.yaml` | Define destinatários age e quais caminhos são cifrados |
| `.gitleaks.toml` | Allowlist para a entropia legítima dos metadados SOPS |
| `.ansible-lint` | Exclui `*.sops.yaml` da regra `yaml[line-length]` (valores cifrados são strings longas por design) |
| `scripts/check-sops-encrypted.sh` (pre-commit local) | Bloqueia commit de qualquer arquivo em `group_vars/` sem metadados `sops:`, ou seja, texto plano |

## Threat Model

**O que protege:**
- Segredos ilegíveis no histórico do GitHub (repositório público).
- Drift de senha entre `.env` e serviço (fonte única versionada).

**O que NÃO protege:**
- Comprometimento do LXC Management com a chave já carregada (a chave em disco decifra tudo que ela é destinatária).
- Segredos já vazados antes desta migração.

**Trade-off aceito:**
- Os segredos permanecem versionados no Git, porém sempre cifrados.
- A segurança passa a depender exclusivamente da proteção da chave privada `age`, e não da disponibilidade de um servidor central de segredos.
