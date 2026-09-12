"""
Demo app: authenticates to Vault via AppRole, requests short-lived dynamic
Postgres credentials, and connects with them. No static DB password is ever
held by the app - only a Vault lease with a TTL.
"""

import os
import time

import hvac
import psycopg2


def read_file(path: str) -> str:
    with open(path) as f:
        return f.read().strip()


def main():
    vault_addr = os.environ["VAULT_ADDR"]
    role_id = read_file(os.environ["VAULT_ROLE_ID_FILE"])
    secret_id = read_file(os.environ["VAULT_SECRET_ID_FILE"])

    client = hvac.Client(url=vault_addr)
    auth = client.auth.approle.login(role_id=role_id, secret_id=secret_id)
    client.token = auth["auth"]["client_token"]
    print("authenticated to Vault via AppRole")

    creds = client.secrets.database.generate_credentials(name="app-readwrite")
    db_user = creds["data"]["username"]
    db_pass = creds["data"]["password"]
    lease_duration = creds["lease_duration"]
    print(f"leased dynamic Postgres credential: {db_user} (TTL: {lease_duration}s)")

    config = client.secrets.kv.v2.read_secret_version(path="app/config")
    print(f"static config from KV: {config['data']['data']}")

    conn = psycopg2.connect(
        host="postgres",
        dbname="appdb",
        user=db_user,
        password=db_pass,
    )
    with conn.cursor() as cur:
        cur.execute("SELECT current_user, now()")
        print("connected as:", cur.fetchone())
    conn.close()

    print("done - this credential will auto-expire and be revoked by Vault at lease end")


if __name__ == "__main__":
    # small delay so vault/postgres containers are ready in compose
    time.sleep(2)
    main()
