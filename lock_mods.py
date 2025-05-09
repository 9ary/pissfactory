import json
import os
import sys

import requests

if (token := os.getenv("CFCORE_API_TOKEN")) is None:
    print(
        "Please set $CFCORE_API_TOKEN "
        "(https://console.curseforge.com/#/api-keys)"
    )
    sys.exit(1)

with open(sys.argv[1]) as f:
    manifest = json.load(f)
file_ids = [m["fileID"] for m in manifest["files"]]

cf_extras = [
    # Corpse x Curios API Compat
    # https://www.curseforge.com/minecraft/mc-mods/corpse-x-curios-api-compat
    # Project ID: 1138130
    6235713,
    # Custom FoV
    # https://www.curseforge.com/minecraft/mc-mods/custom-fov
    # Project ID: 303938
    4600447,

    # Create
    # https://www.curseforge.com/minecraft/mc-mods/create
    # Project ID: 328085
    5838779,
    # Create Deco
    # https://www.curseforge.com/minecraft/mc-mods/create-deco
    # Project ID: 509285
    5293982,
    # Create: Steam 'n' Rails
    # https://www.curseforge.com/minecraft/mc-mods/create-steam-n-rails
    # Project ID: 688231
    5840017,
    # Create: Estrogen
    # https://www.curseforge.com/minecraft/mc-mods/estrogen
    # Project ID: 850410
    6052639,

    # Project Red - Core
    # https://www.curseforge.com/minecraft/mc-mods/project-red-core
    # Project ID: 228702
    6107610,
    # Project Red - Integration
    # https://www.curseforge.com/minecraft/mc-mods/project-red-integration
    # Project ID: 229045
    6107616,
    # Project Red - Transmission
    # https://www.curseforge.com/minecraft/mc-mods/project-red-transmission
    # Project ID: 478939
    6107617,
    # Project Red - Fabrication
    # https://www.curseforge.com/minecraft/mc-mods/project-red-fabrication
    # Project ID: 230111
    6107614,
    # CodeChicken Lib
    # https://www.curseforge.com/minecraft/mc-mods/codechicken-lib-1-8
    # Project ID: 242818
    5753868,
    # CB Multipart
    # https://www.curseforge.com/minecraft/mc-mods/cb-multipart
    # Project ID: 258426
    5311521,

    # Alternate Current
    # https://www.curseforge.com/minecraft/mc-mods/alternate-current
    # Project ID: 548115
    4721662,
    # BoccHUD
    # https://www.curseforge.com/minecraft/mc-mods/bocchud
    # Project ID: 916504
    5492423,
    # Capable Cauldrons
    # https://www.curseforge.com/minecraft/mc-mods/capable-cauldrons
    # Project ID: 826695
    5372761,
    # Capable Composters
    # https://www.curseforge.com/minecraft/mc-mods/capable-composters
    # Project ID: 826696
    4970677,
    # Ears
    # https://www.curseforge.com/minecraft/mc-mods/ears
    # Project ID: 412013
    6166552,
    # Global GameRules
    # https://www.curseforge.com/minecraft/mc-mods/global-gamerules
    # Project ID: 227657
    4587490,
    # KeyBind Bundles
    # https://www.curseforge.com/minecraft/mc-mods/keybind-bundles
    # Project ID: 1172594
    6122719,
    # MaFgLib
    # https://www.curseforge.com/minecraft/mc-mods/mafglib
    # Project ID: 910766
    5579436,
    # Observable
    # https://www.curseforge.com/minecraft/mc-mods/observable
    # Project ID: 509575
    5643037,
    # Portable Hole
    # https://www.curseforge.com/minecraft/mc-mods/portable-hole
    # Project ID: 682568
    4612371,
    # Scholar
    # https://www.curseforge.com/minecraft/mc-mods/scholar
    # Project ID: 961802
    6368136,
    # Simple Voice Chat
    # https://www.curseforge.com/minecraft/mc-mods/simple-voice-chat
    # Project ID: 416089
    6374606,
    # Sound Physics Remastered
    # https://www.curseforge.com/minecraft/mc-mods/sound-physics-remastered
    # Project ID: 535489
    6399601,
    # Squake Reforged
    # https://www.curseforge.com/minecraft/mc-mods/squake-reforged
    # Project ID: 1100654
    5763195,
    # Tweakerge
    # https://www.curseforge.com/minecraft/mc-mods/tweakerge
    # Project ID: 915857
    5633999,
    # [TaCZ] Timeless and Classics Zero
    # https://www.curseforge.com/minecraft/mc-mods/timeless-and-classics-zero
    # Project ID: 1028108
    6069384,
]

other_extras = [
    {
        "displayName": "AE2 EMI Crafting Integration",
        "URL": "https://gitlab.com/talchas/ae2-emi-crafting-forge",
        "fileName": "ae2-emi-crafting-forge-1.3.1.jar",
        "downloadUrl": "https://gitlab.com/talchas/ae2-emi-crafting-forge/-/package_files/169558228/download", # noqa: 501
        "hashes": [
            {"value": "f7ab876581c48b9843de1d8499dc133ef0a64f0a", "algo": 1},
        ]
    }
]

r = requests.post(
    "https://api.curseforge.com/v1/mods/files",
    headers={
        "X-Api-Key": token,
        "Content-Type": "application/json",
    },
    json={
        "fileIds": file_ids + cf_extras,
    },
)
cf_mods = {m["modId"]: m for m in r.json()["data"]}
bad_keys = [
    "downloadCount",
    "fileStatus",
    "gameVersions",
    "isAvailable",
    "sortableGameVersions",
]


def normalize_cf_mod(mod):
    for k in bad_keys:
        mod.pop(k, None)
    if mod.get("downloadUrl") is None:
        id = mod["id"]
        upper = int(id / 1000)
        lower = id % 1000
        filename = mod["fileName"]
        mod["downloadUrl"] = \
            f"https://edge.forgecdn.net/files/{upper}/{lower}/{filename}"
    return mod


cf_mods = sorted(
    (normalize_cf_mod(m) for m in cf_mods.values()),
    key=lambda m: m["modId"],
)
with open("mods.json", "w") as f:
    json.dump(cf_mods + other_extras, f, indent=2)
