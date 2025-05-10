import json
import os
import sys

import requests

cf_api = "https://api.curseforge.com/v1"
if (token := os.getenv("CFCORE_API_TOKEN")) is None:
    print("$CFCORE_API_TOKEN is unset, falling back to curse.tools proxy.")
    print(
        "To use the CurseForge API directly, get a token from "
        "https://console.curseforge.com/#/api-keys"
    )
    cf_api = "https://api.curse.tools/v1/cf"

with open(sys.argv[1]) as f:
    manifest = json.load(f)
removed_projects = [
    # Corpse x Curios API Compat
    # We run a newer version
    1138130,
    # Crafting Station JEI edition
    # We run the upstream version because this is just worse
    956084,
]
cf_files = {
    m["projectID"]: m["fileID"] for m in manifest["files"]
    if m["projectID"] not in removed_projects
}

cf_extras = {
    # Corpse x Curios API Compat
    # https://www.curseforge.com/minecraft/mc-mods/corpse-x-curios-api-compat
    1138130: 6235713,
    # Crafting Station
    # https://www.curseforge.com/minecraft/mc-mods/crafting-station
    318551: 4770683,
    # Custom FoV
    # https://www.curseforge.com/minecraft/mc-mods/custom-fov
    303938: 4600447,

    # Create
    # https://www.curseforge.com/minecraft/mc-mods/create
    328085: 5838779,
    # Create Deco
    # https://www.curseforge.com/minecraft/mc-mods/create-deco
    509285: 5293982,
    # Create: Steam 'n' Rails
    # https://www.curseforge.com/minecraft/mc-mods/create-steam-n-rails
    688231: 5840017,
    # Create: Estrogen
    # https://www.curseforge.com/minecraft/mc-mods/estrogen
    850410: 6052639,

    # Project Red - Core
    # https://www.curseforge.com/minecraft/mc-mods/project-red-core
    228702: 6107610,
    # Project Red - Integration
    # https://www.curseforge.com/minecraft/mc-mods/project-red-integration
    229045: 6107616,
    # Project Red - Transmission
    # https://www.curseforge.com/minecraft/mc-mods/project-red-transmission
    478939: 6107617,
    # Project Red - Fabrication
    # https://www.curseforge.com/minecraft/mc-mods/project-red-fabrication
    230111: 6107614,
    # CodeChicken Lib
    # https://www.curseforge.com/minecraft/mc-mods/codechicken-lib-1-8
    242818: 5753868,
    # CB Multipart
    # https://www.curseforge.com/minecraft/mc-mods/cb-multipart
    258426: 5311521,

    # Alternate Current
    # https://www.curseforge.com/minecraft/mc-mods/alternate-current
    548115: 4721662,
    # BoccHUD
    # https://www.curseforge.com/minecraft/mc-mods/bocchud
    916504: 5492423,
    # Capable Cauldrons
    # https://www.curseforge.com/minecraft/mc-mods/capable-cauldrons
    826695: 5372761,
    # Capable Composters
    # https://www.curseforge.com/minecraft/mc-mods/capable-composters
    826696: 4970677,
    # Ears
    # https://www.curseforge.com/minecraft/mc-mods/ears
    412013: 6166552,
    # Global GameRules
    # https://www.curseforge.com/minecraft/mc-mods/global-gamerules
    227657: 4587490,
    # KeyBind Bundles
    # https://www.curseforge.com/minecraft/mc-mods/keybind-bundles
    1172594: 6122719,
    # MaFgLib
    # https://www.curseforge.com/minecraft/mc-mods/mafglib
    910766: 5579436,
    # Observable
    # https://www.curseforge.com/minecraft/mc-mods/observable
    509575: 5643037,
    # Portable Hole
    # https://www.curseforge.com/minecraft/mc-mods/portable-hole
    682568: 4612371,
    # Scholar
    # https://www.curseforge.com/minecraft/mc-mods/scholar
    961802: 6368136,
    # Simple Voice Chat
    # https://www.curseforge.com/minecraft/mc-mods/simple-voice-chat
    416089: 6374606,
    # Sound Physics Remastered
    # https://www.curseforge.com/minecraft/mc-mods/sound-physics-remastered
    535489: 6399601,
    # Squake Reforged
    # https://www.curseforge.com/minecraft/mc-mods/squake-reforged
    1100654: 5763195,
    # Tweakerge
    # https://www.curseforge.com/minecraft/mc-mods/tweakerge
    915857: 5633999,
    # [TaCZ] Timeless and Classics Zero
    # https://www.curseforge.com/minecraft/mc-mods/timeless-and-classics-zero
    1028108: 6069384,
}
for id in cf_extras.keys():
    if id in cf_files:
        print(f"Overriding upstream mod with project ID {id}!")
cf_files.update(cf_extras)

other_extras = [
    {
        # https://gitlab.com/talchas/ae2-emi-crafting-forge
        "displayName": "AE2 EMI Crafting Integration",
        "fileName": "ae2-emi-crafting-forge-1.3.1.jar",
        "downloadUrl": "https://gitlab.com/talchas/ae2-emi-crafting-forge/-/package_files/169558228/download", # noqa: 501
        "sha1": "f7ab876581c48b9843de1d8499dc133ef0a64f0a",
    },
]

r = requests.post(
    f"{cf_api}/mods/files",
    headers={
        "X-Api-Key": token,
        "Content-Type": "application/json",
    },
    json={
        "fileIds": list(cf_files.values()),
    },
)
cf_mods = {m["modId"]: m for m in r.json()["data"]}
kept_keys = [
    "id",
    "modId",
    "displayName",
    "fileName",
    "downloadUrl",
]


def normalize_cf_mod(mod):
    ret = {k: mod[k] for k in kept_keys}
    ret["sha1"] = next(h["value"] for h in mod["hashes"] if h["algo"] == 1)
    if mod.get("downloadUrl") is None:
        id = mod["id"]
        upper = int(id / 1000)
        lower = id % 1000
        filename = mod["fileName"]
        ret["downloadUrl"] = \
            f"https://edge.forgecdn.net/files/{upper}/{lower}/{filename}"
    return ret


cf_mods = sorted(
    (normalize_cf_mod(m) for m in cf_mods.values()),
    key=lambda m: m["modId"],
)
with open("mods.json", "w") as f:
    json.dump(cf_mods + other_extras, f, indent=2)
