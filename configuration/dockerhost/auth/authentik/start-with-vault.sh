#!/bin/bash

# --- Configurações ---
VAULT_ADDR="https://vault.home"
# MUDANÇA: Lê do arquivo, não tem nada hardcoded
ROLE_ID_FILE="/etc/vault/authentik.roleid"
SECRET_ID_FILE="/etc/vault/authentik.secretid"

# --- Validações ---
if [ ! -f "$ROLE_ID_FILE" ] || [ ! -f "$SECRET_ID_FILE" ]; then
    echo "❌ Erro: Arquivos de credenciais não encontrados em /etc/vault/"
    exit 1
fi

ROLE_ID=$(cat "$ROLE_ID_FILE")
SECRET_ID=$(cat "$SECRET_ID_FILE")

echo "🔐 Conectando ao Vault (AppRole Authentik)..."

# 1. Autenticar
VAULT_TOKEN=$(curl -s --insecure --request POST \
  --data "{\"role_id\":\"$ROLE_ID\", \"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

if [ "$VAULT_TOKEN" == "null" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "❌ Falha ao autenticar."
    exit 1
fi

# 2. Buscar Segredo
echo "🔍 Buscando senha..."
DB_PASSWORD=$(curl -s --insecure --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv/data/authentik/database" | jq -r '.data.data.password')

# 3. Subir
export POSTGRES_PASSWORD="$DB_PASSWORD"
docker compose up -d
unset POSTGRES_PASSWORD
