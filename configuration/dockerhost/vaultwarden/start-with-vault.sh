#!/bin/bash

# --- Configurações ---
VAULT_ADDR="https://vault.home"
ROLE_ID="bef4ab40-1c69-214d-7a9f-6b3da992bdf0" 
SECRET_ID_FILE="/etc/vault/vaultwarden.secretid"
ENV_OUTPUT_FILE="/opt/services/vaultwarden/.env.injected"

# --- Validações ---
if [ ! -f "$SECRET_ID_FILE" ]; then
    echo "❌ Erro: SecretID não encontrado em $SECRET_ID_FILE"
    exit 1
fi
SECRET_ID=$(cat "$SECRET_ID_FILE")

echo "🔐 Conectando ao Vault (AppRole Vaultwarden)..."

# 1. Autenticar
VAULT_TOKEN=$(curl -s --insecure --request POST \
  --data "{\"role_id\":\"$ROLE_ID\", \"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" == "null" ]; then
    echo "❌ Falha na autenticação AppRole."
    exit 1
fi

# 2. Buscar Segredos
echo "🔍 Buscando ADMIN_TOKEN..."
SECRETS_JSON=$(curl -s --insecure --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv/data/services/vaultwarden")

ADMIN_TOKEN=$(echo "$SECRETS_JSON" | jq -r '.data.data.admin_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
    echo "❌ Falha ao obter admin_token."
    exit 1
fi

# 3. Injetar
echo "ADMIN_TOKEN=$ADMIN_TOKEN" > "$ENV_OUTPUT_FILE"

# 4. Executar
echo "🚀 Subindo Vaultwarden..."
docker compose up -d
