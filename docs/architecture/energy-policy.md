### Política de Energia e Custos

* **Meta de Eficiência:** Priorizar hardware com baixo TDP (Thermal Design Power) para serviços 24/7.
* **Automação (NUT):**
    * Se a bateria do UPS cair para < 50%, o Raspberry Pi (NUT Server) ordena o desligamento gracioso do cluster Kubernetes e VMs de laboratório.
    * Se < 10%, desliga o Proxmox (Host).
* **Wake-on-LAN (WoL):** Os serviços sazonais (Kubernetes, VMs de laboratório, Minecraft, etc) serão mantidos desligados (VMs em estado Stopped). Um script simples ou botão no Home Assistant/Dashboard poderão acionar a API do Proxmox para ligá-los apenas quando necessário, economizando RAM e CPU.
