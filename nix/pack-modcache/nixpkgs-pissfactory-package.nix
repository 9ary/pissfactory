{ ... }:
{
  fetchurl,
  lib,
  linkFarmFromDrvs,
  ...
}:
let
  inherit (lib.lists)
    elemAt
    filter
    map
    optional
    ;
  inherit (lib.strings) fromJSON readFile;
in
linkFarmFromDrvs "pack-modcache" (
  map (
    mod:
    let
      hashes =
        mod.hashes or [ ]
        ++ optional (mod ? sha1) {
          algo = 1;
          value = mod.sha1;
        };
    in
    fetchurl {
      url = mod.downloadUrl;
      sha1 = (elemAt (filter (v: v.algo == 1) hashes) 0).value;
    }
  ) (fromJSON (readFile ../../mods.json))
)
