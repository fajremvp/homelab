## Política de Energia e Custos

* **Meta de Eficiência:** Priorizar hardware com baixo TDP (Thermal Design Power) para serviços 24/7.
* **Topologia NUT (Network UPS Tools - Arquitetura Primary/Secondary):**
    * **Primary Node (Edge / Raspberry Pi):**
        * Responsabilidade: Conectado via USB ao Nobreak Intelbras. Lê os sensores brutos, injeta `override.battery.charge.low = 50` e expõe a telemetria na porta `3493`.
        * Regra de Ouro (FSD): O driver utiliza `ignorelb` com `override.battery.charge.low = 50`. A condição `LB` é determinada quando `battery.charge < 50` ou `battery.runtime < battery.runtime.low` (atualmente 300 segundos). A comparação é estrita: a carga não precisa atingir exatamente 50%, e a autonomia estimada também pode antecipar a condição. Com o nobreak operando em bateria (`OB LB`), o `upsmon` Primary declara `FSD` e coordena o desligamento dos clientes. O script `ups-kill.sh` aguarda 140 segundos para permitir o encerramento do Proxmox e a exportação segura do ZFS, antes de enviar o comando de corte ao nobreak e desligar o Raspberry Pi.
    * **Secondary Node (Proxmox Host):**
        * Responsabilidade: Assina o feed do Primary. Ao receber o evento `FSD`, invoca `/sbin/shutdown -h +0`. O Proxmox gerencia o ACPI de desligamento reverso das VMs e desmonta o pool ZFS com segurança na janela temporal fornecida pelo Primary, aguardando o corte mecânico do relé do Nobreak.
* **Wake-on-LAN (WoL):** Os serviços sazonais (Kubernetes, VMs de laboratório, Minecraft, etc) serão mantidos desligados (VMs em estado Stopped). Um script simples ou botão no Home Assistant/Dashboard poderão acionar a API do Proxmox para ligá-los apenas quando necessário, economizando RAM e CPU.
