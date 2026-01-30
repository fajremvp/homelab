# Threat Model — LUKS & Swap

Este documento descreve o modelo de ameaça relacionado à criptografia de disco (LUKS) e à área de swap no servidor Proxmox.

O foco é **proteção de dados em repouso (Data at Rest)** contra acesso físico não autorizado.

---

## LUKS (Full Disk Encryption)

### O que protege
- Roubo físico do servidor.
- Apreensão física (busca e apreensão).
- Acesso offline aos discos.
- Extração de dados diretamente dos SSDs/NVMe.

Todos os dados do sistema, VMs, containers, logs e metadados ficam **ilegíveis sem a chave**.

### O que NÃO protege
- Ataques com o servidor ligado.
- Extração de chaves da memória RAM (Cold Boot Attack).
- Comprometimento do sistema após o boot (root comprometido).

---

## Swap Criptografado (ZFS)

### Objetivo de Segurança
- Evitar que páginas de memória sensíveis sejam escritas em disco em texto claro.
- Garantir que dados temporários (RAM paginada) herdem a criptografia do pool ZFS.

### Impacto
- Dados em swap permanecem protegidos em repouso.
- Não adiciona proteção contra ataques com o sistema em execução.

---

## Impacto de Performance

### LUKS
- Overhead de CPU (AES-NI): ~2–5%.
- Redução de throughput sequencial: ~10–30% (mitigada com flags de performance).
- Impacto desprezível para o Intel Core i5-12400.

### Swap
- Swap é usado apenas em cenários extremos.
- Impacto de performance é irrelevante no uso normal.
- Benefício principal é estabilidade do sistema.

---

## Conclusão

A combinação de:
- ZFS Mirror
- LUKS2
- Swap dentro do pool criptografado fornece um bom equilíbrio entre **segurança física**, **estabilidade** e **performance** para um servidor doméstico 24/7.
