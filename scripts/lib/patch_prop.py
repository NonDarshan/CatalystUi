#!/usr/bin/env python3
import argparse
from pathlib import Path


def load_props(path: Path):
    if not path.exists():
        return []
    return path.read_text(encoding="utf-8", errors="ignore").splitlines()


def upsert_props(lines, kv):
    keys = {k for k, _ in kv}
    out = []
    seen = set()

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            out.append(line)
            continue

        key = stripped.split("=", 1)[0]
        if key in keys:
            value = dict(kv)[key]
            out.append(f"{key}={value}")
            seen.add(key)
        else:
            out.append(line)

    for key, value in kv:
        if key not in seen:
            out.append(f"{key}={value}")

    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prop-file", required=True)
    parser.add_argument("--set", action="append", default=[])
    args = parser.parse_args()

    pairs = []
    for entry in args.set:
        if "=" not in entry:
            raise ValueError(f"Invalid --set entry: {entry}")
        k, v = entry.split("=", 1)
        pairs.append((k, v))

    path = Path(args.prop_file)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = load_props(path)
    updated = upsert_props(lines, pairs)
    path.write_text("\n".join(updated) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
