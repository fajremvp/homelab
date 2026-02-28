# Raspberry Pi (Management Node & Out-of-Band)

## Função e Filosofia
O Raspberry Pi atua como um nó de borda (Edge Node), fisicamente separado da infraestrutura principal. Ele é descartável, substituível e não armazena segredos persistentes da infraestrutura crítica.

* **Localização:** Conectado diretamente ao Modem da ISP (Rede WAN/Untrusted).
* **Segurança:** Não possui chaves privadas SSH do servidor principal.
* **Storage:** Sem criptografia de disco (LUKS) para garantir boot autônomo sem intervenção humana (evita deadlock "Ovo e Galinha").

---

## Serviços em Execução

### 1. NUT Server (Network UPS Tools)
* **Hardware:** Conectado via USB ao Nobreak Ragtech.
* **Função:** Monitora tensão, carga e estado da bateria.
* **Comunicação:** Expõe o status via rede (Porta 3493) ou VPN (Tailscale) para que o Proxmox (Slave) saiba quando iniciar o desligamento gracioso.
* **Por que no Pi?** Evita *bootloops* no servidor principal (onde o servidor liga, detecta bateria baixa via USB e desliga imediatamente). O Pi atua como árbitro externo.

### 2. Emergency VPN (Tailscale)
* **Objetivo:** Permitir acesso remoto (Out-of-Band) para desbloqueio de disco (LUKS) via Dropbear.
* **Implementação:**
    * O RPi atua como um *Subnet Router*, anunciando a rota `192.168.1.0/24` (Rede do Modem).
    * O serviço roda diretamente no OS (sem Docker) para máxima resiliência.
* **ACLs (Restrição via Painel):**
    * **Tag:** `tag:rpi`.
    * **Política:** Acesso de saída permitido **estritamente** para `192.168.1.200:2222`.
    * **Bloqueio:** Qualquer tentativa de acesso lateral (SSH no próprio RPi ou acesso à LAN doméstica) é bloqueada pela ACL da VPN.
* **Estado:** A chave de autenticação é configurada via Ansible (`hardening_rpi.yml`). Em caso de roubo, a revogação da máquina no painel Tailscale corta o acesso imediatamente.

### 3. DNS Secundário (AdGuard Home)
* **Função:** Alta Disponibilidade. Se o AdGuard principal (LXC no Proxmox) cair ou estiver reiniciando, os clientes DHCP alternam automaticamente para este IP.
* **Segurança Forense (Zero Footprint):**
    * **Dados em RAM:** O diretório de dados (`/opt/AdGuardHome/data`) é montado em `tmpfs` com permissão estrita (`mode=0700`).
    * **Consequência:** Ao desligar a energia, todo o cache e histórico desaparecem fisicamente. Não há persistência no cartão SD.
* **Privacidade:** Configurado com `querylog: false` e `statistics: false` na raiz. Logs do daemon silenciados no Systemd.

### 4. Observabilidade (Node Exporter)
* **Função:** Expõe métricas de hardware (CPU, RAM, Temperatura, Disco) para o Prometheus central.
* **Porta:** 9100/TCP.
* **Segurança:** Apenas leitura. Firewall configurado para aceitar conexões vindas do DockerHost.

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
