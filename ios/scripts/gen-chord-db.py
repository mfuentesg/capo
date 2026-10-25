#!/usr/bin/env python3
"""Builds CapoRendering/Resources/chords.json from @tombatossals/chords-db (run from repo root).

Guitar only (the web has no other instrument).
Compact shape: {"guitar": {"strings": n, "chords": {key: {suffix: [[baseFret, [frets], [barres], [fingers]], ...]}}}}
Midi and the capo flag are dropped; every position is kept, as on the web.
"""
import json, pathlib

root = pathlib.Path("node_modules/@tombatossals/chords-db/lib")
out = {}
for name in ("guitar",):
    data = json.loads((root / f"{name}.json").read_text())
    chords = {}
    for key, variations in data["chords"].items():
        chords[key] = {
            v["suffix"]: [[p["baseFret"], p["frets"], p["barres"], p["fingers"]] for p in v["positions"]]
            for v in variations
        }
    out[name] = {"strings": data["main"]["strings"], "chords": chords}
dest = pathlib.Path("ios/Packages/CapoUI/Sources/CapoRendering/Resources/chords.json")
dest.parent.mkdir(parents=True, exist_ok=True)
dest.write_text(json.dumps(out, separators=(",", ":"), sort_keys=True))
print(dest, dest.stat().st_size)
