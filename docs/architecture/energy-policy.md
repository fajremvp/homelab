## Política de Energia e Custos

* **Meta de Eficiência:** Priorizar hardware com baixo TDP (Thermal Design Power) para serviços 24/7.
* **Topologia NUT (Network UPS Tools):**
    * **Master (Controlador):** Raspberry Pi. Conectado via USB ao Nobreak.
        * Responsabilidade: Ler sensores e publicar status. Não toma decisões de desligamento para outros, apenas informa "On Battery" (OB) ou "Low Battery" (LB).
    * **Slave (Monitor):** Proxmox Host.
        * Responsabilidade: Assina o feed do Master.
        * **Regra de Ouro:** Se a bateria do UPS cair para < 50%, o Raspberry Pi (NUT Server) ordena o desligamento gracioso do cluster Kubernetes e VMs de laboratório. Se Bateria < 10% (LB), executa script de shutdown gracioso (parando VMs na ordem correta).
* **Wake-on-LAN (WoL):** Os serviços sazonais (Kubernetes, VMs de laboratório, Minecraft, etc) serão mantidos desligados (VMs em estado Stopped). Um script simples ou botão no Home Assistant/Dashboard poderão acionar a API do Proxmox para ligá-los apenas quando necessário, economizando RAM e CPU.
