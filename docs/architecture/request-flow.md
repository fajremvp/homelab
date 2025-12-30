## Fluxo de Requisição e Responsabilidades (Defense in Depth)

* **Conceito:** Cada camada filtra um tipo específico de ameaça, afunilando o tráfego até chegar limpo à aplicação ("Security Funnel").

| Camada | Ferramenta | Responsabilidade (O que ela faz) | Tipo de Bloqueio |
| :--- | :--- | :--- | :--- |
| **1. Borda (Network)** | **OPNsense** | Filtra conexões brutas (TCP/UDP). | Geo-blocking (bloqueia países), Listas Negras de IP, Proteção contra Scanners de Porta. |
| **2. Inteligência** | **CrowdSec (Bouncer)** | Lê logs de toda a pilha e atualiza o OPNsense. | Se alguém ataca o site, o CrowdSec bane o IP no OPNsense, impedindo qualquer acesso futuro à rede. |
| **3. Ingresso (App)** | **Traefik** | Entende HTTP/HTTPS. | Roteamento por domínio (`app.home`), terminação SSL, Headers de segurança e **Rate Limiting** (evita flood em rotas específicas). |
| **4. Identidade** | **Authentik** | Valida QUEM está entrando. | **Zero Trust:** Nenhuma requisição chega ao app sem um token válido. Gerencia MFA e SSO. |
| **5. Host (Micro-seg)** | **nftables (Host)** | Firewall interno do Linux. | Impede que um container hackeado acesse outros serviços lateralmente (Ex: Container do Site não pode acessar o banco do Vault). |
