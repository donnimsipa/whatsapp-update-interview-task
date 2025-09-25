#!/usr/bin/env python3
"""Flexible WhatsApp dataset generator with Python fallback."""
from __future__ import annotations

import argparse
import json
import math
import random
from datetime import datetime, timezone
from pathlib import Path

VALID_PHONES = [
    "081234567890",
    "085678901234",
    "082345678901",
    "083456789012",
    "087890123456",
]
UNIFORM_PHONES = [
    "081234567890",
    "6285678901234",
    "082345678901",
    "0834-5678-9012",
    "85678901234",
]
INVALID_PHONES = [
    "+630123456",
    "7123456789",
    "08123",
    "abcde12345",
    "",
    "620123456789",
]
VALID_NAMES = [
    "DEWI LESTARI SARI",
    "MAYA SARI PUTRI",
    "RINA PERMATA ANGGRAINI",
    "LINDA MARLINA SIREGAR",
]
INVALID_NAMES = [
    "INVALID FORMAT ONE",
    "INVALID FORMAT TWO",
    "INVALID FORMAT THREE",
    "INVALID FORMAT FOUR",
]


def parse_args() -> argparse.Namespace:
    today = datetime.now(timezone.utc).strftime("%d-%m-%Y")
    parser = argparse.ArgumentParser(description="Generate WhatsApp datasets")
    parser.add_argument("--output", default="outputs/samples/generated-whatsapp.csv")
    parser.add_argument("--records", type=int, default=1000)
    parser.add_argument(
        "--mode",
        choices=["valid", "invalid", "mixed", "uniform"],
        default="valid",
    )
    parser.add_argument("--valid-ratio", type=float, default=0.5)
    parser.add_argument("--patients-json", default="")
    parser.add_argument("--date", default=today)
    return parser.parse_args()


def ensure_dir(path: str) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)


def make_nik(base: int, idx: int) -> str:
    return f"{base + idx:016d}"


def build_rows(args: argparse.Namespace) -> list[list[str]]:
    rows = [["last_updated_date", "nik_identifier", "name", "phone_number"]]
    valid_target = int(math.floor(args.records * args.valid_ratio))
    valid_count = 0

    for i in range(args.records):
        if args.mode == "invalid":
            nik_seed = make_nik(9_000_000_000_000_000, i)
            phone = INVALID_PHONES[i % len(INVALID_PHONES)]
            nik_value = "" if phone == "" else nik_seed
            name = INVALID_NAMES[i % len(INVALID_NAMES)]
            rows.append([args.date, nik_value, name, phone])
        elif args.mode == "mixed":
            if valid_count < valid_target:
                nik = make_nik(3_200_000_000_000_000, i)
                phone = VALID_PHONES[i % len(VALID_PHONES)]
                name = VALID_NAMES[i % len(VALID_NAMES)]
                rows.append([args.date, nik, name, phone])
                valid_count += 1
            else:
                nik_seed = make_nik(9_000_000_000_000_000, i)
                phone = INVALID_PHONES[i % len(INVALID_PHONES)]
                nik_value = "" if phone == "" else nik_seed
                name = INVALID_NAMES[i % len(INVALID_NAMES)]
                rows.append([args.date, nik_value, name, phone])
        elif args.mode == "uniform":
            nik = make_nik(3_100_000_000_000_000, i)
            phone = UNIFORM_PHONES[i % len(UNIFORM_PHONES)]
            name = f"PATIENT_{i + 1}"
            rows.append([args.date, nik, name, phone])
        else:  # valid
            nik = make_nik(3_300_000_000_000_000, i)
            phone = random.choice(VALID_PHONES)
            name = random.choice(VALID_NAMES)
            rows.append([args.date, nik, name, phone])
    return rows


def write_csv(path: str, rows: list[list[str]]) -> None:
    ensure_dir(path)
    with open(path, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(",".join(row) + "\n")


def write_patients_json(path: str, records: int) -> None:
    ensure_dir(path)
    patients = {"patients_before_phone_update": []}
    for i in range(records):
        nik = make_nik(3_000_000_000_000_000, i)
        patients["patients_before_phone_update"].append(
            {
                "resource": {
                    "resourceType": "Patient",
                    "id": f"patient-{i + 1}",
                    "active": True,
                    "identifier": [
                        {
                            "system": "https://fhir.kemkes.go.id/id/nik",
                            "value": nik,
                        }
                    ],
                    "name": [
                        {
                            "use": "official",
                            "family": f"PATIENT_{i + 1}",
                            "given": ["TEST"],
                        }
                    ],
                    "telecom": [],
                    "meta": {
                        "versionId": "v001",
                        "lastUpdated": "2025-08-22T10:15:30.123456+07:00",
                    },
                }
            }
        )
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(patients, fh, indent=2)


def main() -> None:
    args = parse_args()
    rows = build_rows(args)
    write_csv(args.output, rows)
    print(f"[ok] CSV written to {args.output} ({args.records} rows, mode={args.mode})")

    if args.patients_json:
        write_patients_json(args.patients_json, args.records)
        print(f"[ok] Patients JSON written to {args.patients_json}")


if __name__ == "__main__":
    random.seed(42)
    main()
