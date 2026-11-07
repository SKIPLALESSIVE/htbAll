#!/usr/bin/env python3

import json
import subprocess

URL = "https://airsnacks.htb/checkout/boarding-pass/verify"
COOKIE_FILE = "/tmp/airsnacks.cookies"


def field(value, width, name):
    value = str(value).upper()

    if len(value) > width:
        raise ValueError(
            f"{name}: longueur {len(value)} supérieure à {width}"
        )

    return value.ljust(width)


def generate_bcbp():
    fields = [
        ("Format",               "M",        1),
        ("Number of legs",       "1",        1),
        ("Passenger name",       "DOE/JOHN", 20),
        ("Electronic ticket",    "E",        1),
        ("PNR",                   "ABC1234",  7),
        ("Origin",                "CDG",      3),
        ("Destination",           "JFK",      3),
        ("Airline",               "AF",       3),
        ("Flight number",         "0123A",    5),
        ("Julian date",           "297",      3),
        ("Cabin class",           "Y",        1),
        ("Seat",                  "012A",     4),
        ("Check-in sequence",     "0001 ",    5),
        ("Passenger status",      "1",        1),
        ("Conditional length",    "14",       2),
    ]

    raw = ""
    offset = 0

    print("=== BCBP STRUCTURE ===")

    for name, value, width in fields:
        encoded = field(value, width, name)

        print(
            f"[{offset:02d}:{offset + width:02d}] "
            f"{name:<22} {encoded!r}"
        )

        raw += encoded
        offset += width

    assert len(raw) == 60

    # Données conditionnelles
    # >5 : indicateur de version 5
    # 0B : item 10 = 11 caractères
    # 11 espaces : données uniques de test
    # 00 : longueur des données répétées
    unique_data = (
        " "      # Item 15 : Passenger description
        + " "    # Item 12 : Check-in source
        + " "    # Item 14 : Boarding pass issuance source
        + "6297" # Item 22 : Date of issue
        + "B"    # Item 16 : Boarding pass
        + "AF "  # Item 21 : Issuing carrier
    )

    assert len(unique_data) == 11
    conditional_data = ">50B" + unique_data + "03" + (" " * 3)

    assert len(conditional_data) == 20
    assert int(raw[58:60], 16) == len(conditional_data)

    raw += conditional_data

    return raw


def verify_bcbp(raw):
    result = subprocess.run(
        [
            "curl",
            "-sk",
            "-b", COOKIE_FILE,
            "-c", COOKIE_FILE,
            "-w", "\nHTTP_STATUS:%{http_code}",
            "-X", "POST",
            URL,
            "-H", "Content-Type: application/json",
            "-d", json.dumps({"raw": raw}),
        ],
        capture_output=True,
        text=True,
        check=True,
    )

    response, _, status = result.stdout.rpartition(
        "\nHTTP_STATUS:"
    )

    print("\n=== API RESPONSE ===")
    print("HTTP status:", status)

    try:
        print(json.dumps(json.loads(response), indent=2))
    except json.JSONDecodeError:
        print(response)


if __name__ == "__main__":
    raw = generate_bcbp()

    print("\n=== GENERATED BCBP ===")
    print(repr(raw))
    print("Total length:", len(raw))
    print("Conditional length:", int(raw[58:60], 16))
    print("Item 10:", raw[62:64])

    verify_bcbp(raw)
