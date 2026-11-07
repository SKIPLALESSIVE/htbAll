import os, subprocess, time, uuid
from confluent_kafka import Consumer, KafkaError

KAFKA_BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
DLQ_TOPIC = os.environ.get("DLQ_TOPIC", "aidx.flightleg.dlq.v1")
GROUP_ID = os.environ.get("GROUP_ID", "aidx-dlq-drainer")
QUARANTINE_DIR = os.environ.get("QUARANTINE_DIR", "/var/lib/aidx/quarantine")
FORMATTER = os.environ.get("AIDX_FORMATTER",
                           "/var/lib/clickhouse/user_files/aidx_quarantine.py")
CH_PW_FILE = os.environ.get("CH_PW_FILE", "/etc/partner-sync/ch.pw")
DRAIN_SECONDS = int(os.environ.get("DRAIN_SECONDS", "10"))

def _pw():
    try:
        with open(CH_PW_FILE) as fh: return fh.read().strip()
    except OSError: return ""

def _record(reason, byte_len, root_tag, preview, qfile):
    def esc(s): return s.replace("\\", "\\\\").replace("'", "\\'")
    q = ("INSERT INTO aidx_ops.failed_ingest "
         "(id, reason, byte_len, root_tag, preview, quarantine_path, received_at) "
         f"VALUES ('{esc(uuid.uuid4().hex)}', '{esc(reason)}', {int(byte_len or 0)}, "
         f"'{esc(root_tag)}', '{esc(preview)}', '{esc(qfile)}', now())")
    subprocess.run(["clickhouse-client", "--user", "default",
                    "--password", _pw(), "-q", q], check=False)

def _format(raw):
    p = subprocess.run(["python3", FORMATTER], input=raw,
                       capture_output=True, check=False)
    parts = p.stdout.decode("utf-8", "replace").strip().split("\t")
    return tuple(parts) if len(parts) == 3 else (str(len(raw)), "UNKNOWN", "")

def main():
    os.makedirs(QUARANTINE_DIR, exist_ok=True)
    c = Consumer({"bootstrap.servers": KAFKA_BOOTSTRAP, "group.id": GROUP_ID,
                  "auto.offset.reset": "earliest", "enable.auto.commit": False})
    c.subscribe([DLQ_TOPIC])
    deadline = time.time() + DRAIN_SECONDS
    while time.time() < deadline:
        msg = c.poll(1.0)
        if msg is None: continue
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF: continue
            continue
        raw = msg.value() or b""
        reason = "unknown"
        for k, v in (msg.headers() or []):
            if k == "reason": reason = (v or b"").decode("utf-8", "replace"); break
        qfile = os.path.join(QUARANTINE_DIR, f"{int(time.time())}_{uuid.uuid4().hex[:8]}.xml")
        try:
            with open(qfile, "wb") as fh: fh.write(raw)
        except OSError: qfile = ""
        byte_len, root_tag, preview = _format(raw)
        _record(reason, byte_len, root_tag, preview, qfile)
        c.commit(msg, asynchronous=False)
    c.close()

if __name__ == "__main__":
    main()