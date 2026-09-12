# Least-privilege policy for the demo app's AppRole.
# It can read dynamic DB credentials and its own KV config - nothing else.

path "database/creds/app-readwrite" {
  capabilities = ["read"]
}

path "secret/data/app/config" {
  capabilities = ["read"]
}
