## Fluxo de Requisição e Responsabilidades (Defense in Depth)

* **Conceito:** Cada camada filtra um tipo específico de ameaça, afunilando o tráfego até chegar limpo à aplicação ("Security Funnel").

| Camada | Ferramenta | Responsabilidade (O que ela faz) | Tipo de Bloqueio |
| :--- | :--- | :--- | :--- |
| **1. Resolução (DNS)** | **AdGuard Home** | Primário: LXC que resolve `app.home` para o IP do DockerHost (`10.10.30.10`), localizado na VLAN 30. Secundário: Raspberry Pi (Edge), failover do primário (0 footprint). | Bloqueio de domínios maliciosos e rastreadores antes mesmo da conexão iniciar. |
| **2. Borda (Network)** | **OPNsense** | Filtra conexões brutas (TCP/UDP). | Geo-blocking (bloqueia países), Listas Negras de IP, Proteção contra Scanners de Porta. |
| **3. Inteligência** | **CrowdSec (Bouncer)** | Lê logs de toda a pilha e atualiza o OPNsense. | Se alguém ataca o site, o CrowdSec bane o IP no OPNsense, impedindo qualquer acesso futuro à rede. |
| **4. Ingresso (App)** | **Traefik** | Entende HTTP/HTTPS. | Roteamento por domínio (`app.home`), terminação SSL, Headers de segurança e **Rate Limiting** (evita flood em rotas específicas). |
| **5. Identidade** | **Authentik** | Valida QUEM está entrando. | **Zero Trust:** Nenhuma requisição chega ao app sem um token válido. Gerencia MFA e SSO. |
| **6. Host (Micro-seg)** | **nftables (Host)** | Firewall interno do Linux. | Impede que um container hackeado acesse outros serviços lateralmente (Ex: Container do Site não pode acessar o banco do Vault). |

### Diagrama do Fluxo (Request Lifecycle)

```
graph TD
    Client[Client (Arch/Mobile)] -->|1. DNS Query (app.home)| AdGuard[AdGuard Home (LXC)]
    AdGuard -->|1.1 IP Response (10.10.30.10)| Client
    Client -->|2. HTTPS Request| OPNsense[OPNsense Firewall]
    OPNsense -->|3. Allow Traffic| Traefik[Traefik Proxy (DockerHost)]
    Traefik -->|4. Router Match| Authentik[Authentik Middleware]
    Authentik -->|5. Auth OK| Container[App Container (Whoami/Services)]
```
