"""Offline integrity check of API-owned snapshots; not a cross-repo freshness claim."""

import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "contracts"
for name in ["recipe-draft", "imports", "shopping"]:
    manifest = json.loads((root / f"{name}.v1.manifest.json").read_text())
    schema = root / f"{name}.v1.schema.json"
    assert (
        hashlib.sha256(schema.read_bytes()).hexdigest() == manifest["schema_sha256"]
    ), name
    for path, checksum in manifest.get("fixtures", {}).items():
        assert hashlib.sha256((root / path).read_bytes()).hexdigest() == checksum, path
    if "fixtures_sha256" in manifest:
        assert (
            hashlib.sha256((root / f"{name}.v1.fixtures.json").read_bytes()).hexdigest()
            == manifest["fixtures_sha256"]
        )
print("PASS: contract snapshot hashes; API generator remains authoritative")
