{ ... }:
{
  fetchurl,
  lib,
  linkFarmFromDrvs,
  ...
}:
let
  inherit (lib.lists) elemAt filter map;
  inherit (lib.strings) fromJSON readFile;
in
linkFarmFromDrvs "pack-modcache" (
  map (
    mod:
    fetchurl {
      url = mod.downloadUrl;
      sha1 = (elemAt (filter (v: v.algo == 1) mod.hashes) 0).value;
    }
  ) (fromJSON (readFile ../../../mods.json))
)
