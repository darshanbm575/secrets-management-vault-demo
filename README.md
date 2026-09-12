# Secrets Management with HashiCorp Vault

A runnable demo of dynamic secrets: instead of an app holding a long-lived database password in an env var, it authenticates to Vault and requests short-lived, automatically-expiring credentials at startup.

## Why this exists

Static secrets (a DB password baked into a `.env` file or a Kubernetes Secret) are a liability the moment they're created — they don't expire, they get copied into logs and CI variables, and revoking one usually means a deploy. Dynamic secrets flip that: Vault creates a unique credential per app instance with a short TTL, and revokes it automatically when the lease expires.

## What this demonstrates

```
┌──────────┐   1. authenticate (AppRole)   ┌───────┐
│   app    │ ────────────────────────────► │ Vault │
│          │ ◄──────────────────────────── │       │
└──────────┘   2. short-lived DB creds     └───┬───┘
     │                                          │ 3. creates a scoped
     │ 4. connect with leased creds             │    Postgres role
     ▼                                          ▼
┌──────────┐                              ┌──────────┐
│ Postgres │ ◄────────────────────────────│ Postgres │
└──────────┘                              └──────────┘
```

- **AppRole auth**: the app authenticates with a `role_id`/`secret_id` pair, not a static token
- **Database secrets engine**: Vault generates a unique Postgres username/password per lease, with a TTL
- **Automatic revocation**: when the lease expires (or is revoked), Vault drops the Postgres role — the credential simply stops working
- **KV secrets engine**: also demonstrated for static-but-rotatable app config (API keys, etc.)

## Repo layout

```
docker-compose.yml       # Vault (dev mode) + Postgres + the demo app
vault/init.sh             # configures Vault: auth methods, secrets engines, policies
vault/policies/app.hcl    # least-privilege policy the app's AppRole is bound to
app/                       # Python app: authenticates, pulls dynamic DB creds, connects
ROTATION.md                # rotation patterns for both dynamic and static secrets
```

## Running it

```bash
docker compose up -d vault postgres
./vault/init.sh          # enables AppRole + database engine, writes the app policy
docker compose up app    # app authenticates, requests creds, connects to Postgres
```

Watch the app logs — it prints the leased (auto-generated) Postgres username it received from Vault, which is different every run.

## Rotation

See [`ROTATION.md`](ROTATION.md). Short version: dynamic secrets rotate themselves (new lease per app start, TTL-bound); for the handful of secrets that must stay static (a third-party API key Vault can't generate), rotation is a scheduled Vault Agent template re-render plus a documented manual step with the vendor.
