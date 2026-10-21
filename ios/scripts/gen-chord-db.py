#!/usr/bin/env python3
"""Builds CapoRendering/Resources/chords.json from @tombatossals/chords-db (run from repo root).

Compact shape: {instrument: {"strings": n, "chords": {key: {suffix: [[baseFret, [frets], [barres]], ...]}}}}
Fingers, midi and the capo flag are dropped; at most 4 positions per chord are kept.
"""
import json, pathlib

root = pathlib.Path("node_modules/@tombatossals/chords-db/lib")
out = {}
for name in ("guitar", "ukulele"):
    data = json.loads((root / f"{name}.json").read_text())
    chords = {}
    for key, variations in data["chords"].items():
        chords[key] = {
            v["suffix"]: [[p["baseFret"], p["frets"], p["barres"]] for p in v["positions"][:4]]
            for v in variations
        }
    out[name] = {"strings": data["main"]["strings"], "chords": chords}
dest = pathlib.Path("ios/Packages/CapoUI/Sources/CapoRendering/Resources/chords.json")
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(out, separators=(",", ":"), sort_keys=True))
print(dest, dest.stat().st_size)
