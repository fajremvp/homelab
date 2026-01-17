# Raspberry Pi (Management Node & Out-of-Band)

## Função e Filosofia
O Raspberry Pi atua como um nó de borda (Edge Node), fisicamente separado da infraestrutura principal. Ele é descartável, substituível e não armazena segredos persistentes da infraestrutura crítica.

* **Localização:** Conectado diretamente ao Modem da ISP (Rede WAN/Untrusted).
* **Segurança:** Não possui chaves privadas SSH do servidor principal.
* **Storage:** Sem criptografia de disco (LUKS) para garantir boot autônomo sem intervenção humana (evita deadlock "Ovo e Galinha").

---

## Serviços em Execução

### 1. NUT Server (Network UPS Tools) [Master]
* **Hardware:** Conectado via USB ao Nobreak Ragtech.
* **Função:** Monitora tensão, carga e estado da bateria.
* **Comunicação:** Expõe o status via rede (Porta 3493) ou VPN (Tailscale) para que o Proxmox (Slave) saiba quando iniciar o desligamento gracioso.
* **Por que no Pi?** Evita *bootloops* no servidor principal (onde o servidor liga, detecta bateria baixa via USB e desliga imediatamente). O Pi atua como árbitro externo.

### 2. Emergency VPN (Tailscale/Headscale)
* **Objetivo:** Permitir acesso remoto (Out-of-Band) caso o OPNsense ou Proxmox falhem.
* **ACLs (Restrição):**
    * Este nó (`rpi-mgmt`) tem permissão de saída **apenas** para o IP do Dropbear do Proxmox (`192.168.x.x:2222` ou IP de emergência).
    * Bloqueado acesso lateral a qualquer outra VLAN ou serviço interno.
* **Estado:** O arquivo de estado da VPN (`tailscaled.state`) é o único dado persistente de identidade. Se o Pi for roubado, a revogação deste nó no painel administrativo invalida o acesso imediatamente.

### 3. DNS Secundário (AdGuard Home)
* **Função:** Failover. Se o AdGuard principal (LXC no Proxmox) cair, os clientes DHCP alternam para este IP.
* **Privacidade:** Logs de consulta desativados ou mantidos estritamente em RAM (`querylog_enabled: false`), garantindo que o Pi não retenha histórico de navegação.

---

## Modelo de Ameaça (Threat Model)

### Cenário: Roubo Físico ou Clonagem do SSD
* **Impacto:** O atacante obtém o hardware e o sistema operacional.
* **Mitigação:**
    1. **Sem Segredos:** Não há chaves SSH privadas, senhas de banco de dados ou tokens de API do Vault no disco.
    2. **Sem Acesso Lateral:** O Pi reside na rede "suja" do modem. O Firewall (OPNsense) trata o Pi como uma rede externa/hostil.
    3. **DoS de Energia:** O pior cenário é o atacante falsificar um sinal de "Bateria Crítica" no NUT, forçando o desligamento dos servidores. Risco aceito em troca da simplicidade de gerenciamento.

### Cenário: Comprometimento Remoto
* **Mitigação:** O Pi não expõe portas para a internet (exceto o túnel VPN de saída). A gestão é feita via SSH restrito à chave Ed25519 do administrador.

## Notas de Configuração (Debian 13 / RPi OS)

### Relógio de Hardware (RTC)
Diferente de versões antigas, o Debian 13 exige configuração via Device Tree.
- **Config:** `/boot/firmware/config.txt` deve conter `dtoverlay=i2c-rtc,ds3231`.
- **Limpeza:** O pacote `fake-hwclock` deve ser removido para evitar conflitos de tempo no boot.

### Rede
O gerenciamento de rede é feito exclusivamente via **NetworkManager** (`nmcli`). O arquivo `/etc/dhcpcd.conf` é obsoleto e ignorado.
