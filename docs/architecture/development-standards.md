# Padrões de Desenvolvimento e Qualidade (CI/CD Local)

Este documento define as ferramentas, configurações e decisões técnicas que garantem a qualidade, segurança e padronização do código neste repositório.

## Filosofia: Shift-Left Security
Adotei a política de **Shift-Left**, onde a validação ocorre na estação de trabalho do desenvolvedor (antes do `git commit`), e não em produção. Isso reduz o ciclo de feedback e previne que segredos ou código quebrado entrem no histórico do Git.

---

## Pipeline de Validação (Pre-Commit)

Utilizamos o framework [pre-commit](https://pre-commit.com/) para gerenciar hooks de Git.

| Ferramenta | ID(s) | Função | Bloqueio |
| :--- | :--- | :--- | :--- |
| **Higiene de Código** | `trailing-whitespace`, `end-of-file-fixer` | Remove espaços inúteis e garante quebra de linha no final dos arquivos automaticamente. | Auto-Fix |
| **Integridade e Segurança Básica** | `check-added-large-files`, `check-merge-conflict`, `detect-private-key` | Bloqueia o commit de arquivos binários gigantes, marcas de conflito (`<<<<`) e chaves privadas (`id_rsa`, `.pem`). | Crítico (Block) |
| **Gitleaks** | `gitleaks` | **Segurança Avançada.** Escaneia o código em busca de tokens de API e credenciais vazadas. Executa ocultando os valores nos logs de erro (`--redact`). | Crítico (Block) |
| **Ansible Lint** | `ansible-lint` | **Boas Práticas.** Valida playbooks focando em erros fatais e depreciações (utilizando o perfil `--profile basic`). | Crítico (Block) |
| **Yamllint** | `yamllint` | **Sintaxe.** Valida a estrutura YAML utilizando regras mais flexíveis (*relaxed*) e ignorando o tamanho máximo de linha. Ignora templates Jinja do Ansible (`.j2`). | Crítico (Block) |
| **ShellCheck** | `shellcheck` | **Lógica.** Analisa scripts `.sh` em busca de erros de sintaxe e problemas de portabilidade (utilizando wrapper Python sem necessidade de Docker). | Crítico (Block) |
| **SOPS Encryption Check** | `sops-encryption-check` (hook local) | **Segurança de Segredos.** Bloqueia commit de qualquer arquivo em `group_vars/*.sops.yaml` sem metadados `sops:`, prevenindo vazamento de texto plano. | Crítico (Block) |

### Exceções de Lint
O arquivo `.ansible-lint` na raiz exclui `configuration/inventory/group_vars/**/*.sops.yaml` da regra `yaml[line-length]`. Valores cifrados pelo SOPS são strings base64 longas por design do formato — não é uma violação de estilo a ser corrigida.

## Estratégia de Versionamento e Releases (Tags)

O ciclo de vida da infraestrutura é marcado e tageado utilizando um modelo híbrido de **Calendar Versioning (CalVer)** aliado a sufixos descritivos.

**Formato Padrão:** `vYYYY.MM.DD-[descrição-curta]`
* Exemplo: `v2026.07.04-sops-zero-touch`

### Quando criar uma nova Release/Tag?
O Homelab não é tageado a cada pequeno commit (ex: atualizações de serviços, pequenos ajustes em dashboards, ou typos no README). As tags são reservadas estritamente para **Marcos Arquiteturais**:

1. **Adoção de Novas Ferramentas Core:** (Ex: Adoção de um novo sistema de identidade/autenticação, substituição do Ansible por outra ferramenta de automação).
2. **Descomissionamento de Infraestrutura:** Remoção definitiva de serviços pesados ou VMs (Ex: Aposentadoria do HashiCorp Vault).
3. **Mudanças Críticas de Topologia:** Alteração do range de VLANs, reestruturação pesada do Firewall ou mudança de sistema de arquivos base (ZFS/LUKS).

**Por que agir assim?**
As Releases funcionam como *Checkpoints* seguros de "Estado da Arte". Se uma alteração profunda quebrar a infraestrutura no futuro, podemos analisar o código exatamente como ele estava na última Release estável para basear nosso plano de Disaster Recovery ou Rollback.
