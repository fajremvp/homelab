ui = true
disable_mlock = true

storage "raft" {
  path    = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
}

# Garante que redirecionamentos da UI apontem para o Traefik, não para o localhost.
api_addr = "https://vault.home"
cluster_addr = "https://127.0.0.1:8201"
