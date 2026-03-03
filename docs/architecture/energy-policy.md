## Política de Energia e Custos

* **Meta de Eficiência:** Priorizar hardware com baixo TDP (Thermal Design Power) para serviços 24/7.
* **Topologia NUT (Network UPS Tools - Arquitetura Primary/Secondary):**
    * **Primary Node (Edge / Raspberry Pi):**
        * Responsabilidade: Conectado via USB ao Nobreak Intelbras. Lê os sensores brutos, injeta `override.battery.charge.low = 50` e expõe a telemetria na porta `3493`.
        * Regra de Ouro (FSD): Ao atingir 50% de bateria (estimado em ~49min de autonomia real), declara `FSD` na rede. Ele não corta a energia imediatamente. Ele executa um script interceptador (`ups-kill.sh`) que impõe um atraso incondicional (atualmente `130s`) para permitir a evacuação do ZFS no Proxmox, ignorando desconexões prematuras do TCP causadas pelo systemd. Após o delay, atira o sinal hexadecimal de morte para o UPS e desliga a si mesmo.
    * **Secondary Node (Proxmox Host):**
        * Responsabilidade: Assina o feed do Primary. Ao receber o evento `FSD`, invoca `/sbin/shutdown -h +0`. O Proxmox gerencia o ACPI de desligamento reverso das VMs e desmonta o pool ZFS com segurança na janela temporal fornecida pelo Primary, aguardando o corte mecânico do relé do Nobreak.
* **Wake-on-LAN (WoL):** Os serviços sazonais (Kubernetes, VMs de laboratório, Minecraft, etc) serão mantidos desligados (VMs em estado Stopped). Um script simples ou botão no Home Assistant/Dashboard poderão acionar a API do Proxmox para ligá-los apenas quando necessário, economizando RAM e CPU.
