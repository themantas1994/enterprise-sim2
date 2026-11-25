#!/usr/bin/env python3
"""PLAN section 9 data check: every ship data value must carry a non-empty `source`.

Convention (provisional until the first ship file exists): a ship value is a JSON object that has a
"value" key. It must also have a "source" key holding a non-empty string (a ledger id such as D-WARP-004,
or "estimate"). Objects without a "value" key are containers and are walked recursively.

Usage: python3 -I scripts/check_ship_sources.py [dir, default ships]. Exit 1 on any violation.
An empty or missing-file ships/ directory passes, but the script still runs.
"""
import json
import sys
from pathlib import Path


def walk(node, path, errors):
    if isinstance(node, dict):
        if "value" in node:
            src = node.get("source")
            if not isinstance(src, str) or not src.strip():
                errors.append(f"{path}: value without a non-empty 'source'")
        else:
            for k, v in node.items():
                walk(v, f"{path}.{k}", errors)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            walk(v, f"{path}[{i}]", errors)


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "ships"
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
        walk(data, str(f), errors)
    for e in errors:
        print("FAIL:", e, file=sys.stderr)
    print(f"ship sources: {'FAIL' if errors else 'OK'} ({len(files)} file(s) checked in {root})")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
