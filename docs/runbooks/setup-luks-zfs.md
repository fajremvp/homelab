# Runbook — Setup LUKS, Swap e Desbloqueio Remoto (Proxmox + ZFS)

## Contexto

Este documento registra o setup completo de **criptografia LUKS**, **swap seguro em ZFS** e **desbloqueio remoto via Dropbear SSH** em um servidor Proxmox VE headless.

---

## LUKS (Full Disk Encryption)

**Data:** 21/12/2025

**Objetivo:**
Converter o sistema para LUKS **pós-instalação**, mantendo ZFS Mirror como root.

**Guia seguido:**
Encrypt complete Proxmox VE node with LUKS
https://github.com/mr-manuel/proxmox/blob/main/luks-encryption-manual-tpm-ssh-unlock/README.md

**Fluxo executado:**
1. Instalação limpa do Proxmox com ZFS Mirror.
2. Quebra temporária do mirror.
3. Formatação LUKS2 (`AES-XTS-Plain64`, chave efetiva 512-bit).
4. Alinhamento com `--sector-size 4096`.
5. Recriação do mirror via `zfs replace`.
6. Ajustes de performance no `crypttab` (`discard`, flags de workqueue).

**Resultado:** **SUCESSO**.

---

## Swap Seguro (ZFS)

**Data:** 21/12/2025

**Objetivo:**
Evitar travamentos totais (deadlocks) em cenários de exaustão de RAM, garantindo que páginas de memória não sejam escritas em disco sem criptografia.

**Guia seguido:**
Enable swap with ZFS for memory exhaustion
https://github.com/mr-manuel/proxmox/blob/main/zfs-swap/README.md

**Implementação:**
- Swap criado dentro do pool ZFS root já criptografado.
- Herda automaticamente a criptografia LUKS.
- Não exige senha adicional no boot.

**Tamanho:** 16 GB.

**Resultado:** **SUCESSO**.

**Observação técnica:**
- Swap não é usado em operação normal.
- Atua apenas como mecanismo de segurança e estabilidade.
- Não substitui dimensionamento correto de RAM.

---

## Desbloqueio Remoto (Dropbear SSH)

**Data:** 21/12/2025

**Objetivo:**
Permitir o desbloqueio da criptografia LUKS em ambiente **headless**, sem teclado ou monitor conectados.

**Funcionamento:**
- Durante o boot, antes do sistema principal subir, o initramfs inicia uma instância temporária do **Dropbear SSH**.
- O servidor escuta conexões SSH na porta 22.
- O administrador conecta remotamente e digita a senha do LUKS.
- Após o desbloqueio, o boot continua normalmente e o Dropbear é encerrado.

**Resultado:**
Servidor totalmente operacional sem necessidade de acesso físico.
