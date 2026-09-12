#!/usr/bin/env bash
# Configures the dev Vault instance: AppRole auth, the database secrets
# engine (dynamic Postgres creds), a KV mount for static config, and the
# least-privilege policy the app authenticates as.
#
# Requires the `vault` CLI, and `docker compose up -d vault postgres` already
# running. Not for production use - this targets Vault's dev-mode server.

set -euo pipefail

export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_TOKEN="root"

mkdir -p vault/output

echo "==> writing app policy"
vault policy write app-policy vault/policies/app.hcl

echo "==> enabling AppRole auth"
vault auth enable approle 2>/dev/null || echo "  (already enabled)"

vault write auth/approle/role/app-role \
  token_policies="app-policy" \
  token_ttl=15m \
  token_max_ttl=1h \
  secret_id_ttl=24h

echo "==> writing AppRole credentials to vault/output/"
vault read -field=role_id auth/approle/role/app-role/role-id > vault/output/role_id
vault write -field=secret_id -f auth/approle/role/app-role/secret-id > vault/output/secret_id

echo "==> enabling database secrets engine"
vault secrets enable database 2>/dev/null || echo "  (already enabled)"

vault write database/config/appdb \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@postgres:5432/appdb?sslmode=disable" \
  allowed_roles="app-readwrite" \
  username="vaultadmin" \
  password="vaultadmin-local-only"

echo "==> creating dynamic role: app-readwrite (1h TTL)"
vault write database/roles/app-readwrite \
  db_name=appdb \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT CONNECT ON DATABASE appdb TO \"{{name}}\"; \
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

echo "==> enabling KV v2 for static app config"
vault secrets enable -path=secret -version=2 kv 2>/dev/null || echo "  (already enabled)"
vault kv put secret/app/config feature_flag_enabled=true

echo "==> done. AppRole role_id/secret_id written to vault/output/"
