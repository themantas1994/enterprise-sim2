#!/usr/bin/env python3
"""PLAN section 9 data check: every ship data value must carry a non-empty `source`.

Convention (provisional until the first ship file exists): a ship value is a JSON object that has a
"value" key. It must also have a "source" key holding a non-empty string (a ledger id such as D-WARP-004,
or "estimate"). Objects without a "value" key are containers and are walked recursively.

A source is "estimate" or one or more ledger ids separated by commas. Every cited id must exist in the ledger
and be a `verified` row (estimate rows are cited as "estimate", not by id).

Usage: python3 -I scripts/check_ship_sources.py [dir, default ships] [ledger, default docs/sources.md; "-" skips
the ledger check]. Exit 1 on any violation, 2 on a missing directory or ledger.
An empty or missing-file ships/ directory passes, but the script still runs.
"""
import json
import re
import sys
from pathlib import Path

ROW = re.compile(r"^\| ((?:D|ENG)-[A-Z0-9]+-\d{3}) \|")


def load_ledger(path):
    """Return {id: status} from the ledger table (status is the last column)."""
    out = {}
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        m = ROW.match(line)
        if m:
            cols = [c.strip() for c in line.strip().strip("|").split(" | ")]
            out[m.group(1)] = cols[-1]
    return out


def walk(node, path, errors, ledger):
    if isinstance(node, dict):
        if "value" in node:
            src = node.get("source")
            if not isinstance(src, str) or not src.strip():
                errors.append(f"{path}: value without a non-empty 'source'")
            elif ledger is not None:
                for tok in re.split(r"[,\s]+", src.strip()):
                    if not tok or tok == "estimate":
                        continue
                    if tok not in ledger:
                        errors.append(f"{path}: source '{tok}' is not a ledger id")
                    elif ledger[tok] != "verified":
                        errors.append(f"{path}: source '{tok}' is '{ledger[tok]}' in the ledger, not verified")
        else:
            for k, v in node.items():
                walk(v, f"{path}.{k}", errors, ledger)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, f"{path}[{i}]", errors, ledger)


def main() -> int:
    repo = Path(__file__).resolve().parent.parent
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else repo / "ships"
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    ledger_path = None if arg == "-" else Path(arg) if arg else repo / "docs" / "sources.md"
    if ledger_path is not None and not ledger_path.is_file():
        print(f"no such ledger: {ledger_path}", file=sys.stderr)
        return 2
    ledger = load_ledger(ledger_path) if ledger_path else None
    if not root.is_dir():
        print(f"no such dir: {root}", file=sys.stderr)
        return 2
    files = sorted(root.rglob("*.json"))
    errors = []
    for f in files:
        try:
            data = json.loads(f.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            errors.append(f"{f}: unreadable JSON ({e})")
            continue
        walk(data, str(f), errors, ledger)
    for e in errors:
        print("FAIL:", e, file=sys.stderr)
    print(f"ship sources: {'FAIL' if errors else 'OK'} ({len(files)} file(s) checked in {root})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
