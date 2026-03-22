## Fluxo de Requisição e Responsabilidades (Defense in Depth)

* **Conceito:** Cada camada filtra um tipo específico de ameaça, afunilando o tráfego até chegar limpo à aplicação ("Security Funnel").

| Camada | Ferramenta | Responsabilidade (O que ela faz) | Tipo de Bloqueio |
| :--- | :--- | :--- | :--- |
| **1. Resolução (DNS)** | **AdGuard Home** | Primário: LXC que resolve `app.home` para o IP do DockerHost (`10.10.30.10`), localizado na VLAN 30. Secundário: Raspberry Pi (Edge), failover do primário (0 footprint). | Bloqueio de domínios maliciosos e rastreadores antes mesmo da conexão iniciar. |
| **2. Borda (Network)** | **OPNsense** | Filtra conexões brutas (TCP/UDP). | Geo-blocking (bloqueia países), Listas Negras de IP, Proteção contra Scanners de Porta. |
| **3. Inteligência** | **CrowdSec (Bouncer)** | Lê logs de toda a pilha e atualiza o OPNsense. | Se alguém ataca o site, o CrowdSec bane o IP no OPNsense, impedindo qualquer acesso futuro à rede. Perímetro: Bane IPs no Firewall detectados atacando o Traefik/Rede. Obs: Proteção de Login (Authentik) está em modo Monitoramento (sem banimento automático) devido a limitações de parser. |
| **4. Ingresso (App)** | **Traefik** | Entende HTTP/HTTPS. | Roteamento por domínio (`app.home`), terminação SSL, Headers de segurança e **Rate Limiting** (evita flood em rotas específicas). |
| **5. Identidade** | **Authentik** | Valida QUEM está entrando. | **Zero Trust:** Nenhuma requisição chega ao app sem um token válido. Gerencia MFA e SSO. |
| **6. Host (Micro-seg)** | **nftables (Host)** | Firewall interno do Linux. | Impede que um container hackeado acesse outros serviços lateralmente (Ex: Container do Site não pode acessar o banco do Vault). |

### Diagrama do Fluxo (Request Lifecycle)

```
graph TD
    Client[Client (Arch/Mobile)]

    %% Fluxo DNS com Alta Disponibilidade e Soberania
    Client -->|1. DNS Query| PrimaryDNS[AdGuard LXC 10.10.30.5]
    Client -->|1.1 Failover Timeout| SecondaryDNS[AdGuard RPi 192.168.1.5]

    PrimaryDNS -->|2. Upstream| Unbound[Unbound OPNsense]
    SecondaryDNS -->|2. Upstream| Unbound
    Unbound -->|3. Recursion| RootServers((Internet Root Servers))

    %% Fluxo de Resposta
    PrimaryDNS -->|IP: 10.10.30.10| Client
    SecondaryDNS -->|IP: 10.10.30.10| Client

    %% Fluxo de Dados HTTP/TCP
    Client -->|4. Request| OPNsense[OPNsense Firewall]
    OPNsense -->|5. Forward 443| Traefik[Traefik Ingress]
    Traefik <-->|6. Auth Check| Authentik[Authentik]
    Traefik -->|7. Access| App[App/Service]

    %% Bouncer
    CrowdSec[CrowdSec DockerHost] -.->|Block IPs| OPNsense
```
