#!/usr/bin/env python3

import json
import os
import re
import sys

with open(sys.argv[1]) as f:
    mods = json.load(f)

os.makedirs("mods", exist_ok=True)

server_excludes = [
    re.compile(pattern) for pattern in [
        r"oculus-.*\.jar$",
        r"zume-.*\.jar$",
        r"watermedia-.*\.jar$",
        r"embeddium-.*\.jar$",
        r"embeddiumplus-.*\.jar$",
        r"citresewn-.*\.jar$",
        r"LegendaryTooltips-.*\.jar$",
        r"ears-.*\.jar$",
        r"giacomos_speedometer-.*\.jar$",
        r"fancymenu_.*\.jar$",
        r"drippyloadingscreen_.*\.jar$",
    ]
]

for mod in mods:
    side = "client" if any(p.match(mod["fileName"]) for p in server_excludes) else "both"
    hash = next(h["value"] for h in mod["hashes"] if h["algo"] == 1)
    pw = f"""name = "{mod["displayName"]}"
filename = "{mod["fileName"]}"
side = "{side}"

[download]
url = "{mod["downloadUrl"]}"
hash-format = "sha1"
hash = "{hash}"
"""
    with open(f"mods/{mod["fileName"]}.pw.toml", "w") as f:
        f.write(pw)
