# Padrões de Desenvolvimento e Qualidade (CI/CD Local)

Este documento define as ferramentas, configurações e decisões técnicas que garantem a qualidade, segurança e padronização do código neste repositório.

## Filosofia: Shift-Left Security
Adotei a política de **Shift-Left**, onde a validação ocorre na estação de trabalho do desenvolvedor (antes do `git commit`), e não em produção. Isso reduz o ciclo de feedback e previne que segredos ou código quebrado entrem no histórico do Git.

---

## Pipeline de Validação (Pre-Commit)

Utilizamos o framework [pre-commit](https://pre-commit.com/) para gerenciar hooks de Git.

| Ferramenta | ID | Função | Bloqueio |
| :--- | :--- | :--- | :--- |
| **Gitleaks** | `gitleaks` | **Segurança.** Escaneia o código em busca de chaves privadas (RSA, PEM), tokens de API e credenciais hardcoded. | Crítico (Block) |
| **Ansible Lint** | `ansible-lint` | **Boas Práticas.** Verifica playbooks contra regras de idempotência, sintaxe moderna e erros comuns. | Crítico (Block) |
| **Yamllint** | `yamllint` | **Sintaxe.** Valida a indentação e estrutura estrita de arquivos YAML (`docker-compose`, configs). | Crítico (Block) |
| **ShellCheck** | `shellcheck` | **Lógica.** Analisa scripts `.sh` em busca de erros de sintaxe, variáveis não citadas e portabilidade. | Warning |
| **Fixers** | `trailing-whitespace`, `end-of-file` | **Higiene.** Remove espaços inúteis e garante quebra de linha no final dos arquivos automaticamente. | Auto-Fix |
