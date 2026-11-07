import re
import socket
from datetime import datetime, timezone, timedelta

from skyfield.api import EarthSatellite, load, wgs84


HOST = "154.57.164.82"
PORT = 31876
ALTITUDE_THRESHOLD = 30.0

ts = load.timescale()


def recv_until(sock, marker: bytes) -> str:
    data = b""

    while marker not in data:
        chunk = sock.recv(4096)

        if not chunk:
            break

        data += chunk

    return data.decode(errors="replace")


def parse_challenge(text: str):
    line1_match = re.search(r"^(1 .+)$", text, re.MULTILINE)
    line2_match = re.search(r"^(2 .+)$", text, re.MULTILINE)

    station_match = re.search(
        r"\(Lat,Long\):\s*([+-]?\d+(?:\.\d+)?),([+-]?\d+(?:\.\d+)?)",
        text
    )

    if not line1_match or not line2_match or not station_match:
        return None

    line1 = line1_match.group(1).strip()
    line2 = line2_match.group(1).strip()

    lat = float(station_match.group(1))
    lon = float(station_match.group(2))

    return line1, line2, lat, lon


def calculate_windows(line1, line2, lat, lon):
    sat = EarthSatellite(
        line1,
        line2,
        "DIGITWIN HTB",
        ts
    )

    station = wgs84.latlon(
        latitude_degrees=lat,
        longitude_degrees=lon
    )

    now = datetime.now(timezone.utc)

    t0 = ts.from_datetime(now)
    t1 = ts.from_datetime(now + timedelta(hours=24))

    times, events = sat.find_events(
        station,
        t0,
        t1,
        altitude_degrees=ALTITUDE_THRESHOLD
    )

    answer = []
    current_rise = None

    print("\n[+] Events:")

    for t, event in zip(times, events):
        dt = t.utc_datetime().replace(microsecond=0)

        iso = (
            dt.isoformat()
            .replace("+00:00", "Z")
        )

        event_name = {
            0: "RISE",
            1: "CULMINATION",
            2: "SET",
        }[event]

        print(f"    {event_name:12} {iso}")

        if event == 0:
            current_rise = iso

        elif event == 2 and current_rise is not None:
            answer.extend([
                current_rise,
                iso
            ])

            current_rise = None

    return " ".join(answer)


def main():
    with socket.create_connection((HOST, PORT)) as sock:

        while True:

            text = recv_until(
                sock,
                b"When will it be visible next?>"
            )

            if not text:
                print("[!] Connection closed")
                break

            print(text)

            challenge = parse_challenge(text)

            if challenge is None:
                print("[!] No challenge found")

                # flag / success / failure message
                break

            line1, line2, lat, lon = challenge

            print("[+] Parsed:")
            print(f"    TLE1: {line1}")
            print(f"    TLE2: {line2}")
            print(f"    LAT : {lat}")
            print(f"    LON : {lon}")

            answer = calculate_windows(
                line1,
                line2,
                lat,
                lon
            )

            print(f"\n[+] Sending:")
            print(answer)

            sock.sendall(
                answer.encode() + b"\n"
            )


if __name__ == "__main__":
    main()