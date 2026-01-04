# Diário de Bordo

Este arquivo documenta a jornada, erros, aprendizados e decisões diárias.
Para mudanças estruturais formais, veja o [CHANGELOG](../CHANGELOG.md).

---
## 2026-01-04
**Status:** ✅ Sucesso (Refatoração de Segurança)

**Foco:** Migração do Vault para VM Dedicada (Zero Trust Real)

- **Correção de Rumo:**
    - A implementação inicial (Container) violava a política de segmentação da VLAN 40.
    - **Ação:** Destruí o container e provisionei a VM 106 (`Vault`) isolada na VLAN 40.
- **Infraestrutura:**
    - **OPNsense:** Criada VLAN 40 e regra de firewall permitindo apenas `Source: DockerHost` -> `Dest: Vault:8200`.
    - **Traefik:** Configurado *File Provider* para rotear `vault.home` para `http://10.10.40.10:8200` via arquivo dinâmico.
- **Vault Setup:**
    - Instalação nativa (apt) no Debian 13.
    - Configurado `api_addr = "https://vault.home"` para garantir que redirecionamentos de UI passem pelo Proxy reverso.
    - **Resultado:** Unseal realizado com sucesso, chaves salvas e interface protegida pelo Authentik.
## 2026-01-03
**Status:** ✅ Sucesso (Secret Management)

**Foco:** Implementação do HashiCorp Vault

- **Decisão de Versão:**
    - Optado por **Vault v1.21.1** (Latest Stable), garantindo correções de segurança recentes.
- **Implementação:**
    - Backend de armazenamento: **Raft** (Integrated Storage) - elimina dependência do Consul.
    - Proteção de Ingress: Middleware `authentik@docker` aplicado no router do Vault. Apenas admins autenticados chegam na tela de login do cofre.
- **Cerimônia de Inicialização (Unseal):**
    - Executada inicialização com **Shamir's Secret Sharing**.
    - **Configuração:** 5 Key Shares, Threshold de 3 chaves para desbloqueio.
    - **Root Token:** Gerado e armazenado com segurança máxima (Bitwarden, depois para o Vaultwarden) junto com as 5 chaves de unseal.
- **Estado Final:**
    - Vault operacional em `https://vault.home`.
    - Banco de dados criptografado em repouso.
    - Requer desbloqueio manual (3 chaves) a cada reinicialização do container.
## 2026-01-02 (Parte 4)
**Status:** ✅ Sucesso (Hardening RBAC)

**Foco:** Restrição de Acesso via Policy (Python)

- **Objetivo:** Impedir que qualquer usuário logado no Authentik (mesmo sem privilégios) acesse o painel administrativo do Traefik. Apenas a equipe de infraestrutura deve ter acesso.
- **Implementação:**
    - Criado grupo `infra-admins` no Authentik e incluído o usuário administrador.
    - Criada uma **Expression Policy** (Python) para validar a pertinência ao grupo:
      ```python
      return ak_is_group_member(request.user, name="infra-admins")
      ```
    - Vinculada a policy ao aplicativo `Traefik Dashboard` com prioridade 0.
- **Validação:**
    - Login com admin: **Sucesso** (Acesso liberado).
    - Login com usuário comum: **Bloqueado** (Mensagem "Permission Denied" exibida pelo Authentik).
## 2026-01-02 (Parte 3)
**Status:** ✅ Sucesso (Identity Provider & Zero Trust)

**Foco:** Implementação do Authentik e Integração com Traefik (ForwardAuth)

- **Desafio 1 (Erro Operacional):**
    - Durante a configuração dos arquivos `docker-compose.yml`, houve uma **sobrescrita acidental** do arquivo do Authentik com o conteúdo do Traefik. Isso causou a queda de ambos os serviços.
    - *Recuperação:* Foi necessário restaurar manualmente os manifestos YAML corretos em `/opt/auth/authentik` e `/opt/traefik` e recriar os containers (`force-recreate`).
- **Desafio 2 (O Erro 404 no Callback):**
    - Após configurar o middleware, o fluxo de login iniciava, mas falhava no retorno (`/outpost.goauthentik.io/callback...`) com erro 404 do Traefik.
    - **Causa Técnica:** O Traefik bloqueava a URL de callback porque ela não correspondia à regra restrita do Dashboard (`PathPrefix(/dashboard)`).
- **Solução Definitiva (Global Callback Route):**
    - Adicionada uma Label no serviço do Authentik criando um Router dedicado: `Rule=PathPrefix(/outpost.goauthentik.io/)`.
    - Isso instrui o Traefik a interceptar *qualquer* requisição de callback do Authentik, independente do domínio, e encaminhá-la para o container do IdP.
- **Resultado:**
    - Acesso a `https://traefik.home/dashboard/` redireciona para `auth.home`, exige credenciais e retorna com sucesso.
    - Porta 8080 do Traefik foi fechada definitivamente.
## 2026-01-02 (Parte 2)
**Status:** ✅ Sucesso (Hardening)

**Foco:** Segurança do DockerHost e Padronização

- **Motivação:** Antes de implementar a camada de identidade (Authentik), identifiquei que o Traefik mantinha acesso direto e irrestrito ao `docker.sock`. Isso violava o princípio do menor privilégio (Security by Design).
- **Ações de Mitigação:**
    - **Socket Proxy:** Interpus um proxy que filtra chamadas de API. Agora o Traefik só tem permissão para listar containers (`GET`). Comandos destrutivos ou de criação (`POST`, `DELETE`) são bloqueados silenciosamente.
    - **Resiliência de Disco:** Configurei rotação de logs global no Docker Daemon (Max 3 arquivos de 10MB) para evitar que serviços verbosos lotem o armazenamento de 32GB.
    - **OS Patching:** Debian configurado para aplicar patches de segurança automaticamente (`unattended-upgrades`).
    - **Organização:** Migrei serviços dispersos para a hierarquia `/opt/services/` e padronizei o ownership para o usuário comum, removendo a necessidade de operar arquivos como root.
## 2026-01-02
**Status:** ✅ Sucesso Definitivo (Traefik v3.6)

**Foco:** Upgrade para Traefik v3.6 (Latest Stable) e Validação de Ingress

- **Decisão Estratégica:**
    - Optado por não manter a versão legado (v2.11) e migrar imediatamente para **Traefik v3.6** para evitar dívida técnica futura (EOL em Fev/2026).
- **Implementação (The Fix):**
    - Configurado container `traefik:v3.6`.
    - Mantida a variável de ambiente `DOCKER_API_VERSION=1.45`.
    - **Resultado:** A biblioteca client do Traefik v3 respeitou a variável e ignorou a negociação de versão falha, conectando-se perfeitamente ao Docker Engine do Debian 13.
- **Validação Técnica (Headers):**
    - `whoami` reportou `X-Forwarded-Proto: https` (Terminação SSL OK).
    - `X-Real-Ip: 10.10.20.101` (Roteamento de VLANs transparente, sem mascaramento de IP).
    - Logs do Traefik limpos, sem erros de API.
## 2025-12-31
**Status:** ✅ Sucesso (Traefik & Ingress)

**Foco:** Implementação do Proxy Reverso (Traefik) e Compatibilidade Docker API

- **Desafio (Dependency Hell):**
    - O Docker Engine no **Debian 13 (Trixie)** exige API mínima `1.44`.
    - O **Traefik v3** tenta negociar versões antigas (`1.24`) por padrão e falha em ambientes *bleeding edge*.
    - Tentativas de forçar a versão via flags (`--providers.docker.apiVersion`) ou variáveis (`DOCKER_API_VERSION`) no Traefik v3 falharam silenciosamente devido a mudanças recentes na lib interna.
- **Solução (Downgrade Tático):**
    - Revertido para **Traefik v2.11** (LTS).
    - Injetada variável de ambiente `DOCKER_API_VERSION=1.45` diretamente no container.
    - Isso forçou o cliente Docker interno do Traefik a falar a língua do Debian 13 sem negociação.
- **Validação:**
    - Acesso a `https://whoami.home` confirmado.
    - Redirecionamento HTTP -> HTTPS (80 -> 443) ativo.
    - **Header X-Real-IP:** O container recebe o IP real do cliente (`10.10.20.x`), confirmando que o roteamento Inter-VLAN está transparente.
- **Observação:**
    - Atualizar assim que possível para a versão mais recente (v2.11 ends Feb 01, 2026).
## 2025-12-30
**Status:** ✅ Sucesso (DNS & Privacy)

**Foco:** Implementação do AdGuard Home e Gestão de DNS
- **Infraestrutura DNS (LXC Container):**
    - Criado Container LXC `101 (AdGuard-Primary)` baseado em Alpine Linux (3.23) na VLAN 30.
    - **Specs:** 1 Core, 256MB RAM, IP Estático `10.10.30.5`.
    - **Software:** AdGuard Home instalado via script oficial.
        - `curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v`, disponível [aqui](https://github.com/AdguardTeam/AdGuardHome
).
- **Configuração do Serviço (AdGuard):**
    - **Upstreams:** Configurados servidores DNS-over-HTTPS (Cloudflare/Quad9) para garantir privacidade e evitar interceptação de porta 53 pelo ISP.
    - **Reverse DNS:** Apontado para o OPNsense (`10.10.30.1`) para resolução correta de hostnames locais nos logs.
- **Integração de Rede (OPNsense DHCP):**
    - Alterado o servidor DNS entregue via DHCP para as VLANs **TRUSTED (20)** e **IOT (50)**:
        - **De:** `1.1.1.1` e `8.8.8.8` (Externos (Cloudflare e Google, respectivamente).
        - **Para:** `10.10.30.5` (Local (AdGuard)).
    - **Política de Resiliência:** A VLAN **SERVER (30)** teve seu DNS mantido em `1.1.1.1` para evitar dependência cíclica (o DockerHost não deve depender de um container vizinho para resolver nomes durante o boot).
- **Validação:**
    - Cliente Arch Linux (VLAN 20) renovou DHCP e confirmou recebimento do DNS `10.10.30.5` via `/etc/resolv.conf`.
    - Dashboard do AdGuard registrou queries vindas da rede TRUSTED e bloqueios ativos.
    - O mesmo foi realizado com a VLAN 50.
- Documentação do repo melhor documentada e formatada.
- Repo aberto.
## 2025-12-29
**Status:** ✅ Sucesso (Docker & Hardening)

**Foco:** Configuração do DockerHost e Ajuste de Firewall

- **Hardening SSH:**
    - Chaves Ed25519 copiadas do Arch Linux para o DockerHost.
    - **Configuração de Segurança:** Editado `/etc/ssh/sshd_config` para:
        * `PermitRootLogin no` (Bloqueio total de login direto como root via SSH).
        * `PasswordAuthentication no` (Autenticação por senha desativada; apenas chaves SSH).
        * `PubkeyAuthentication yes` (Autenticação por chave pública habilitada).
        * `ChallengeResponseAuthentication no` (Desativa métodos interativos/legados de autenticação).
        * `UsePAM yes` (Mantém PAM ativo para controle de sessão e políticas do sistema).
    - **Validação:** Login verificado com sucesso via chave; tentativa de login por senha rejeitada como esperado.

- **Instalação do Docker:**
    - Utilizado repositório oficial (método compatível com Debian Trixie/Bookworm).
    - Engine e Plugin Compose (v5.0.0) instalados.
    - Usuário adicionado ao grupo `docker` para execução sem root/sudo.
    - **Teste de Sanidade:** `docker run hello-world` executado com sucesso (Pull da imagem via WAN OK, Execução OK).

- **Incidente de Conectividade (Firewall):**
    - *Sintoma:* O Arch Linux (VLAN 20) não conseguia pingar ou conectar via SSH no DockerHost (VLAN 30), resultando em Timeout.
    - *Causa Raiz:* Esquecimento da política de "Default Deny". Embora a VLAN 30 tivesse permissão de saída (para internet), a VLAN 20 não tinha permissão explícita de **entrada/passagem** para a VLAN 30.
    - *Solução:* Criada regra de Firewall na interface **TRUSTED**:
        - **Action:** Pass
        - **Source:** TRUSTED net
        - **Destination:** Any (ou SERVER net)
        - **Justificativa:** Permite que dispositivos de gerenciamento acessem os servidores.
        - O mesmo foi feito com a VLAN 50 (IOT).
## 2025-12-28
**Status:** ⚠️ Resgate de Rede (Driver Migration)

**Foco:** Recuperação das VLANs após mudança para VirtIO

- **O Incidente:**
    - Ao verificar a VM `DockerHost`, notei que ela não pegava IP (estava com APIPA `169.254.x.x`).
    - No OPNsense, as interfaces **TRUSTED**, **SERVER** e **IOT** haviam desaparecido do painel de controle, restando apenas LAN e WAN.
- **Diagnóstico:**
    - A mudança do driver de rede da VM OPNsense (de `e1000` para `VirtIO`) alterou a nomenclatura das interfaces no BSD (de `em0` para `vtnet0/1`).
    - Isso quebrou a associação "Parent Interface" das VLANs, tornando-as órfãs e desativadas.
    - Identifiquei via MAC Address (`04:FD`) que a interface `vtnet1` (atualmente WAN) era, na verdade, a porta física configurada com Trunks no Proxmox.
- **Solução:**
    1. **Reparenting:** Reconfigurei as VLANs 20, 30 e 50 para usarem a interface correta (`vtnet1`) como pai.
    2. **Re-assignment:** Re-adicionei as interfaces lógicas que haviam sumido.
    3. **Re-IP:** Restaurei os IPs Estáticos (`10.10.x.1`) e serviços DHCP que foram limpos durante a falha.
- **Resultado:** A VM DockerHost obteve o IP `10.10.30.102` imediatamente após o fix.
## 2025-12-27
**Status:** ✅ Sucesso

**Foco:** Provisionamento do DockerHost e Segmentação VLAN 30

- **Infraestrutura de Rede (VLAN 30 - SERVER):**
    - Configurada interface lógica no OPNsense (`10.10.30.1/24`) com DHCP ativado (`.100` a `.200`).
    - Validado isolamento: `ping` da VLAN 20 (Trusted) para 50 (IoT) falha como esperado (Bloqueio padrão).
    - Regras de Firewall: Criada regra temporária "Pass All" na VLAN 30 para permitir instalação de pacotes.
- **Computação (VM DockerHost):**
    - Criada VM ID `105` (Debian 13 Minimal (somente com SSH Server e Standard system utilities)).
    - **Specs:** 2 vCores (Host), 8GB RAM (Static), 32GB Disk (VirtIO Block).
    - **Rede:** Interface VirtIO com **Tag 30** definida no Proxmox.
    - **Validação:**
        - VM obteve IP `10.10.30.x` automaticamente.
        - Conectividade externa (WAN) funcionando via NAT Híbrido.
        - Acesso SSH verificado a partir da VLAN 20 (Trusted).
## 2025-12-26
**Status:** ✅ Sucesso Crítico (Rede Funcional)

**Foco:** Troubleshooting de VLANs, Switch e Roteamento OPNsense

- **O Incidente:** O DHCP não chegava aos clientes via Wi-Fi (VLANs 20/50) e, quando chegava (após fix), não havia navegação.
- **Diagnóstico e Soluções (Post-Mortem):**
    1. **Proxmox Bridge Dropping Tags:** A bridge `vmbr0` (VLAN Aware) estava descartando pacotes taggeados (20, 50) antes de entregá-los à VM.
        - *Correção:* Adicionado `bridge-vids 2-4094` em `/etc/network/interfaces` no Host.
        - *Correção:* Adicionado `trunks=20;50` na configuração da interface de rede da VM (`/etc/pve/qemu-server/100.conf`).
    2. **Conflito de Roteamento (Routing Loop):** A interface LAN (`192.168.0.250/24`) e WAN (`192.168.0.50/24`) estavam na mesma sub-rede. O kernel do OPNsense entrava em conflito de rota ao tentar responder a pacotes de outras VLANs, causando erro *"Provide a valid source address"* no Ping.
        - *Solução Definitiva:* Alterado IP da LAN para `192.168.99.1/24` para isolar as redes.
    3. **Hardware Offloading (VirtIO):** Pacotes DHCP chegavam corrompidos/descartados.
        - *Ajuste:* Desativado Hardware CRC, TSO e LRO nas configurações do OPNsense.
    4. **Firewall Block:** VLANs novas vêm com "Default Deny".
        - *Ajuste:* Criadas regras de "Pass All" e configurado Outbound NAT Híbrido.
## 2025-12-25
**Status:** 🔄 Troca de Hardware

**Foco:** Aquisição de Storage para Bitcoin Node

- **Problema Logístico:** O SSD SanDisk (comprado em 14/12) entrou em estado de atraso indefinido no Mercado Livre ("Em preparação" por 10 dias). Compra cancelada para evitar parada no projeto.
- **Revisão Técnica:** Aproveitei o incidente para reavaliar a especificação. Identifiquei que o SanDisk Plus é **DRAM-less**. Para um Full Node Bitcoin, isso seria catastrófico durante o IBD (Initial Block Download), pois o esgotamento do cache SLC derrubaria a velocidade de escrita drasticamente.
- **Decisão:** Adquirido **Samsung 870 EVO 2TB** (Envio Full).
    - Embora o custo seja marginalmente maior, ele possui **2GB de Cache LPDDR4** e controlador MKX. Isso garante que a sincronização da blockchain ocorra na velocidade máxima da interface SATA, economizando dias de espera futura.
    - A placa de rede HP NC364T (incompatível) devolvida também serviu para abater a diferença de custo.
## 2025-12-24
**Status:** ⚠️ Resgate de Rede (Rollback)

**Foco:** Recuperação de Acesso e Simplificação de Rede

- **O Incidente:**
    - Após o sucesso inicial com o Dropbear, tentamos migrar para a topologia "Router-on-a-Stick" configurando VLANs (10, 20, 90) no OPNsense e no Switch.
    - **Resultado:** Perda total de acesso (Lockout). O Dropbear parou de responder e o Proxmox ficou inacessível.
- **Diagnóstico (A Causa Raiz):**
    1. **Hardcoding no Boot:** O arquivo `/etc/initramfs-tools/initramfs.conf` continha uma linha forçando IP Estático (`IP:10.10.10.1...`).
    2. **Desalinhamento:** O Switch foi configurado para esperar VLANs, mas o servidor bootava forçando um IP fora da sub-rede e sem tagging, causando falha de comunicação.
- **A Solução (O Resgate):**
    - **Physical Reset:** Reset físico do Switch TP-Link para configurações de fábrica (Rede Flat 192.168.0.x).
    - **Boot Config:** Editado `initramfs.conf` para remover o IP estático e definir `IP=dhcp`.
    - **Proxmox Config:** Editado `/etc/network/interfaces` para usar DHCP na `vmbr0`.
- **Lição Aprendida:**
    - **NUNCA** definir IPs estáticos no `initramfs` em ambiente de Homelab. Usar `IP=dhcp` e controlar a fixação de IP via reserva no Roteador (DHCP Static Lease).
    - O Dropbear (Desbloqueio) deve permanecer sempre na VLAN Nativa/Untagged (Rede "Burra") para garantir acesso de emergência independente do estado do OPNsense.
## 2025-12-22
**Status:** ✅ Sucesso Total

**Foco:** Otimização de Hardware e Router-on-a-Stick

- **Decisão Técnica:** A placa HP Quad-Port foi removida. O custo de complexidade de driver e energia não justificava o uso, dado que o switch TP-Link gerencia VLANs com perfeição.
- **Troubleshooting Dropbear:** Após a remoção da placa HP, o nome da interface mudou de `enp8s0` para `enp4s0`. Isso quebrou o desbloqueio remoto inicial.
    - *Correção:* Atualizei o `initramfs.conf` com `DEVICE=enp4s0` e fixei a porta `2222`. O teste de `cryptroot-unlock` via SSH no notebook Arch funcionou após limpar o `known_hosts`.
- **OPNsense:** WAN configurada com sucesso na VLAN 90. O IP foi obtido via DHCP do modem em modo DMZ.
## 2025-12-21
**Status:** ✅ Sucesso

**Foco:** Criptografia (FDE), Swap e Desbloqueio Remoto

- **LUKS:** Realizei a conversão pós-instalação do Proxmox para **LUKS2** (Full Disk Encryption) seguindo o guia manual. 
- **Swap:** Configurei um **ZFS Swap de 16GB** para evitar travamentos por exaustão de memória (OOM), já que o ZFS sem swap pode entrar em deadlock.
- **Dropbear:** Configurei o servidor SSH leve (Dropbear) no initramfs.
    - **Teste:** Reiniciei o servidor sem monitor. Conectei via SSH na porta temporária, digitei a senha do disco e o boot do Proxmox prosseguiu corretamente.

## 2025-12-20
**Status:** ✅ Sucesso

**Foco:** Dry Run (Instalação e Rede)

- **Instalação Base:** Instalei o Proxmox VE 9.1 para validar a detecção de hardware.
- **Rede:**
    - A interface Onboard foi identificada como `eno1` (Driver `r8169`).
    - A placa HP Quad-Port foi identificada corretamente (Driver `e1000e`).
    - **Latência:** Teste de ping direto registrou `0.2ms`.
- **Armazenamento:** O **ZFS Mirror (RAID 1)** foi montado e ativado no `rpool` com os dois NVMe Kingston.
- **Troubleshooting:** Tive dificuldade inicial para pingar o servidor (10.10.10.x) a partir do meu Arch Linux.
    - *Solução:* Era necessário ajustar as regras de entrada/saída no firewall do cliente (Arch), pois não há roteador intermediando a conexão física direta neste estágio.

## 2025-12-19
**Status:** ✅ Sucesso

**Foco:** Hardware Burn-in e BIOS

- **Validação de Memória:** Executei o **MemTest86 V11.5** por 6 horas e 17 minutos.
    - **Resultado:** 48/48 testes completados com **0 Erros**.
    - *Telemetria:* XMP validado a 3192 MT/s. A temperatura máxima da CPU ficou em 48°C, validando a instalação do cooler AK400.
![Evidência do MemTest86](../assets/benchmarks/MemTest86.jpeg)
- **Configuração da BIOS:** Apliquei as configurações críticas na Gigabyte B760M.
