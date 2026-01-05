#!/bin/bash

# --- Configurações ---
VAULT_ADDR="https://vault.home"
ROLE_ID="76d922af-d14a-6a1a-4a37-270a3e23953b"
SECRET_ID_FILE="/etc/vault/dockerhost.secretid"

# --- Validações Iniciais ---
if [ ! -f "$SECRET_ID_FILE" ]; then
    echo "❌ Erro: Arquivo de SecretID não encontrado em $SECRET_ID_FILE"
    exit 1
fi
SECRET_ID=$(cat "$SECRET_ID_FILE")

echo "🔐 Conectando ao Vault (AppRole)..."

# --- 1. Autenticar (Pegar Token) ---
VAULT_TOKEN=$(curl -s --insecure --request POST \
  --data "{\"role_id\":\"$ROLE_ID\", \"secret_id\":\"$SECRET_ID\"}" \
  "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

if [ "$VAULT_TOKEN" == "null" ] || [ -z "$VAULT_TOKEN" ]; then
    echo "❌ Falha ao autenticar. Verifique RoleID e o arquivo em /etc/vault."
    exit 1
fi

# --- 2. Buscar o Segredo (Ler a Senha do Banco) ---
echo "🔍 Buscando senha do banco..."
DB_PASSWORD=$(curl -s --insecure --header "X-Vault-Token: $VAULT_TOKEN" \
  "$VAULT_ADDR/v1/kv/data/authentik/database" | jq -r '.data.data.password')

if [ "$DB_PASSWORD" == "null" ] || [ -z "$DB_PASSWORD" ]; then
    echo "❌ Falha ao ler o segredo. Caminho 'kv/authentik/database' existe?"
    exit 1
fi

echo "✅ Senha recuperada com sucesso!"

# --- 3. Injetar e Subir ---
echo "🚀 Subindo Authentik..."
# Exporta a variável para o contexto do docker compose
export POSTGRES_PASSWORD="$DB_PASSWORD"

# Sobe em modo detached
docker compose up -d

# Limpa a variável da memória do shell atual por precaução
unset POSTGRES_PASSWORD
echo "🏁 Authentik iniciado."
