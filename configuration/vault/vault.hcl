ui = true

# Necessário para rodar sem permissões de root extremas
disable_mlock = true

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

# Deve ser a URL pública (Traefik), pois o Firewall bloqueia acesso direto ao IP
api_addr = "https://vault.home"
# Cluster address é interno (comunicação entre nós Raft), usa IP e HTTP (pois TLS está off no listener)
cluster_addr = "http://10.10.40.10:8201"
