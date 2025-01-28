#!/usr/bin/env python3

import json
import os
import sys

with open(sys.argv[1]) as f:
    mods = json.load(f)

os.makedirs("mods", exist_ok=True)

for mod in mods:
    hash = next(h["value"] for h in mod["hashes"] if h["algo"] == 1)
    pw = f"""name = "{mod["displayName"]}"
filename = "{mod["fileName"]}"
side = "both"

[download]
url = "{mod["downloadUrl"]}"
hash-format = "sha1"
hash = "{hash}\""""
    with open(f"mods/{mod["fileName"]}.pw.toml", "w") as f:
        f.write(pw)
