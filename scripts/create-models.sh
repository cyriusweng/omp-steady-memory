#!/usr/bin/env bash
# Create (or refresh) the steady-memory mental models on a Hindsight bank.
# Token resolution: HINDSIGHT_TOKEN env var, else parsed from your local OMP
# config.yml. Never commit your token.
set -euo pipefail

URL="${HINDSIGHT_URL:-http://localhost:8888}"
BANK="${HINDSIGHT_BANK_ID:-}"
TOKEN="${HINDSIGHT_TOKEN:-}"
CONFIG="${OMP_CONFIG:-$HOME/.omp/agent/config.yml}"
MODELS_FILE="$(cd "$(dirname "$0")/.." && pwd)/models/steady-memory-models.json"

if [ -z "$TOKEN" ] && [ -f "$CONFIG" ]; then
  TOKEN=$(awk '/^  apiToken:/{v=$2; gsub(/^[\"\x27]|[\"\x27]$/, "", v); print v; exit}' "$CONFIG")
fi
if [ -z "$BANK" ] && [ -f "$CONFIG" ]; then
  BANK=$(awk '/^  bankId:/{v=$2; gsub(/^[\"\x27]|[\"\x27]$/, "", v); print v; exit}' "$CONFIG")
fi
: "${TOKEN:?Set HINDSIGHT_TOKEN or add hindsight.apiToken to $CONFIG}"
: "${BANK:?Set HINDSIGHT_BANK_ID or add hindsight.bankId to $CONFIG}"

python3 - "$MODELS_FILE" "$URL" "$BANK" "$TOKEN" <<'PY'
import json, sys, urllib.error, urllib.request

models_file, base, bank, token = sys.argv[1:5]
models = json.load(open(models_file))["models"]

def call(method, path, body=None):
    req = urllib.request.Request(
        base + path,
        method=method,
        headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body else None,
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read() or b"{}")

for m in models:
    exists = False
    try:
        call("GET", f"/v1/default/banks/{bank}/mental-models/{m['id']}")
        exists = True
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    if exists:
        print(f"{m['id']}: already exists, refreshing")
        call("POST", f"/v1/default/banks/{bank}/mental-models/{m['id']}/refresh")
    else:
        print(f"{m['id']}: creating")
        body = {k: m[k] for k in ("id", "name", "source_query", "max_tokens", "trigger") if k in m}
        call("POST", f"/v1/default/banks/{bank}/mental-models", body)

print("Done. Content is generated server-side in the background.")
print("Check inside an OMP session with: /memory mm list  then  /memory mm show <id>")
PY
