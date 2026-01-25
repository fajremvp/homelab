#!/bin/bash

# --- Configurações ---
VAULT_ADDR="https://vault.home"
# MUDANÇA: Lê do arquivo
ROLE_ID_FILE="/etc/vault/vaultwarden.roleid"
SECRET_ID_FILE="/etc/vault/vaultwarden.secretid"
ENV_OUTPUT_FILE="/opt/services/vaultwarden/.env.injected"

# --- Validações ---
if [ ! -f "$ROLE_ID_FILE" ] || [ ! -f "$SECRET_ID_FILE" ]; then
    echo "❌ Erro: Arquivos de credenciais não encontrados em /etc/vault/"
    exit 1
fi

ROLE_ID=$(cat "$ROLE_ID_FILE")
SECRET_ID=$(cat "$SECRET_ID_FILE")

echo "🔐 Conectando ao Vault (AppRole Vaultwarden)..."

# 1. Autenticar
VAULT_TOKEN=$(curl -s --insecure --request POST \
  --data "{\"role_id\":\"$ROLE_ID\", \"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

if [ -z "$VAULT_TOKEN" ] || [ "$VAULT_TOKEN" == "null" ]; then
    echo "❌ Falha na autenticação."
    exit 1
fi

# 2. Buscar Segredos
echo "🔍 Buscando ADMIN_TOKEN..."
SECRETS_JSON=$(curl -s --insecure --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv/data/services/vaultwarden")

ADMIN_TOKEN=$(echo "$SECRETS_JSON" | jq -r '.data.data.admin_token')

# 3. Injetar e Subir
echo "ADMIN_TOKEN=$ADMIN_TOKEN" > "$ENV_OUTPUT_FILE"
docker compose up -d
