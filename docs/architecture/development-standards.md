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
