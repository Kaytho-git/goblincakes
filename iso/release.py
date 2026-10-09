#!/usr/bin/env python3
"""Splits the ISO into parts under 2 GB (GitHub Releases' limit per file) and writes
goblincakes-iso.json, which the GOBLINCAKES USB creator reads to find, check and put
the parts back together:

  iso/release.py <iso> <out-dir> <variant-id> <name> <description>

The manifest lists every variant in the release (more ISO kinds can be added later:
"Bara installera", Nvidia); this run adds/replaces one variant in an existing
manifest in <out-dir> if there is one.
"""
import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

PART_SIZE = 1900 * 1024 * 1024  # under GitHub's 2 GiB, a multiple of 4 KiB (sector aligned)
CHUNK = 8 * 1024 * 1024


def main(iso, out_dir, variant_id, name, description):
    iso, out_dir = Path(iso), Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    total = hashlib.sha256()
    parts = []
    with iso.open("rb") as src:
        index = 0
        while True:
            part_name = f"{iso.name}.part{index:02d}"
            part_hash = hashlib.sha256()
            size = 0
            with (out_dir / part_name).open("wb") as dst:
                while size < PART_SIZE:
                    data = src.read(min(CHUNK, PART_SIZE - size))
                    if not data:
                        break
                    dst.write(data)
                    part_hash.update(data)
                    total.update(data)
                    size += len(data)
            if size == 0:
                (out_dir / part_name).unlink()
                break
            parts.append({"name": part_name, "size": size, "sha256": part_hash.hexdigest()})
            print(f"{part_name}: {size} bytes", flush=True)
            index += 1

    manifest_path = out_dir / "goblincakes-iso.json"
    manifest = {"variants": []}
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
    variant = {
        "id": variant_id,
        "name": name,
        "description": description,
        "file": iso.name,
        "size": iso.stat().st_size,
        "sha256": total.hexdigest(),
        "minUsb": 16 if iso.stat().st_size > 7.5e9 else 8,  # GB on the stick's label
        "parts": parts,
    }
    manifest["variants"] = [v for v in manifest["variants"] if v["id"] != variant_id] + [variant]
    manifest["version"] = os.environ.get("GOBLINCAKES_VERSION", iso.stem.removeprefix("GOBLINCAKES-"))
    manifest["built"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False))
    print(f"{manifest_path}: {len(parts)} parts, sha256 {variant['sha256']}")


if __name__ == "__main__":
    if len(sys.argv) != 6:
        sys.exit(__doc__)
    main(*sys.argv[1:])
