### Configuração de Firmware (BIOS) e Validação de Hardware

* **Registro de Validação de Memória (Burn-in):**
    * **Data do Teste:** 19/12/2025
    * **Ferramenta:** MemTest86 V11.5 Free
    * **Duração:** 06:17:03 (48/48 Testes completados)
    * **Resultado:** **PASS (0 Erros)**
    * **Telemetria:**
        * Velocidade da RAM: 3192 MT/s (Confirmação de XMP Ativo)
        * Temperatura Máx CPU: 48°C (Validação da montagem do Cooler AK400)

* **Configuração Obrigatória da BIOS (Gigabyte B760M):**
    * *Alterações aplicadas para garantir performance de ZFS, virtualização e segurança.*

    | Configuração | Valor Definido | Justificativa Técnica |
    | :--- | :--- | :--- |
    | **Extreme Memory Profile (X.M.P)** | `Profile 1` | Garante operação das memórias a 3200MHz. Sem isso, o padrão JEDEC (2133MHz) degradaria severamente a performance do ZFS ARC. |
    | **Intel (VMX) Virtualization Tech** | `Enabled` | Instrução de hardware obrigatória para execução de máquinas virtuais (KVM) no Proxmox. |
    | **VT-d** | `Enabled` | **CRÍTICO.** Habilita IOMMU para permitir o *PCI Passthrough* da placa de rede HP NC364T para a VM do OPNsense. |
    | **AC BACK** | `Always On` | Automação de *Power Recovery*. Garante que o servidor ligue sozinho após o retorno da energia, permitindo que o boot não assistido ocorra. |
    | **Gigabyte Utilities Downloader** | `Disabled` | Segurança. Bloqueia a injeção automática de executáveis/bloatware da placa-mãe no sistema operacional. |
    | **Internal Graphics** | `Enabled` | Mantém a iGPU ativa para transcodificação de vídeo ou diagnóstico, mesmo se houver placa offboard futura. |
    | **CSM Support** | `Disabled` | Força o modo UEFI Puro. O CSM (Legacy) é desativado para garantir compatibilidade com recursos modernos e evitar boot em partições MBR antigas. |
    | **Secure Boot** | `Disabled` | Desativado temporariamente para permitir o carregamento de módulos de kernel não assinados (ZFS) e o bootloader customizado necessário para a criptografia LUKS manual. |
    | **Fast Boot** | `Disabled` | Garante a inicialização completa da stack USB no POST, essencial para que o teclado funcione no momento de digitar a senha do LUKS durante o boot. |
    | **ErP** | `Disabled` | Mantém a placa de rede em *standby* de baixa energia, permitindo o funcionamento futuro de *Wake-on-LAN* se necessário. |