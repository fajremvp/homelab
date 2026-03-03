# Raspberry Pi (Management Node & Out-of-Band)

## Função e Filosofia
O Raspberry Pi atua como um nó de borda (Edge Node), fisicamente separado da infraestrutura principal. Ele é descartável, substituível e não armazena segredos persistentes da infraestrutura crítica.

* **Localização:** Conectado diretamente ao Modem da ISP (Rede WAN/Untrusted).
* **Segurança:** Não possui chaves privadas SSH do servidor principal.
* **Storage:** Sem criptografia de disco (LUKS) para garantir boot autônomo sem intervenção humana (evita deadlock "Ovo e Galinha").

---

## Serviços em Execução

### 1. NUT Server (Network UPS Tools)
* **Função:** Atua como o **Primary Node (Master)**. O RPi é o único equipamento com conexão física (USB) ao Nobreak Intelbras.
* **Por que no Pi?** O servidor Proxmox fica bloqueado na inicialização pelo LUKS. Se o servidor principal comandasse o Nobreak, um "Startup Storm" (energia vai e volta repetidamente) prenderia o sistema. O RPi garante que a ordem de corte de energia seja ditada por uma máquina leve e autônoma.

#### Arquitetura de Comunicação
1. **O Driver (`usbhid-ups`):** Lê os dados USB em *raw*, injeta correções (`override.battery.charge.low = 50`) e expõe as métricas.
2. **O Daemon (`upsd`):** Ouve em `0.0.0.0:3493` e atua como servidor de telemetria.
3. **O Monitor (`upsmon`):** Executa localmente como `primary`. Quando a carga atinge 50% (`OB LB`), ele dispara o evento de *Forced Shutdown (FSD)*.

#### A Engenharia do Shutdown (O Interceptador)
O firmware da Intelbras tem duas limitações graves mapeadas empiricamente:
1. **Delay fixo:** O `ups.delay.shutdown` é travado na placa em 20 segundos (não aceita `offdelay` via software).
2. **Fail-Safe:** O UPS ignora qualquer comando de desligar as tomadas se estiver recebendo energia AC da parede (`OL`). O corte só acontece em `OB`.

Além disso, o fluxo padrão de shutdown do NUT sob `systemd` pode encerrar o driver USB antes da execução do comando final de `load.off`, impedindo o corte físico das tomadas.

**A Mitigação (`ups-kill.sh`):**
O `SHUTDOWNCMD` no `upsmon.conf` do RPi foi alterado para executar um script customizado `/usr/local/bin/ups-kill.sh` que faz o seguinte:

1. **Atraso Incondicional (`sleep 130`):** Cria uma janela de evacuação imutável baseada no tempo real cronometrado de desligamento do Proxmox (83s) + margem de segurança (47s). Isso impede que a desconexão precoce de rede do Proxmox faça o RPi cortar a energia com o ZFS ainda montado.
2. Usa `pkill -9 usbhid-ups` para assassinar o driver (bypasseando o cgroup do systemd que mataria o script junto).
3. Executa `/usr/sbin/upsdrvctl shutdown`, ativando a guilhotina de 20 segundos do hardware.
4. Executa `/sbin/shutdown -h now` para o RPi morrer graciosamente.

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

## Gerenciamento Térmico (Cooling)
**Status:** Refrigeração 100% Passiva (Sem partes móveis).

Apesar do case físico possuir suporte a ventoinha, a refrigeração ativa foi explicitamente removida do projeto em 01/03/2026.
* **Justificativa de Hardware:** Ventoinhas genéricas de baixo custo (Sleeve Bearing) degradam rapidamente em operação 24/7, gerando ruído excessivo e risco de travamento do motor (curto-circuito leve na trilha de 5V).
* **Validação Empírica (Stress Test):** Um teste de 3 minutos de carga a 100% nos 4 núcleos (`stress --cpu 4`) com apenas os dissipadores passivos resultou em um pico de **78.8°C**. A verificação de hardware (`vcgencmd get_throttled`) retornou `0x0`, confirmando ausência total de *Thermal Throttling* (que iniciaria aos 80°C).
* **Cenário Real:** A carga de produção (NUT, Tailscale, DNS) mantém a CPU predominantemente em *Idle* (~45°C).
* **Evidência:** O log do benchmark está arquivado em `docs/assets/benchmarks/rpi4_thermal_stress.txt`.

### Rede
O gerenciamento de rede é feito exclusivamente via **NetworkManager** (`nmcli`). O arquivo `/etc/dhcpcd.conf` é obsoleto e ignorado.
