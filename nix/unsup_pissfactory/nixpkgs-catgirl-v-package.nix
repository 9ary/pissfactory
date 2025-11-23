{ ... }:
{
  fetchurl,
  lib,
  ...
}:
let
  inherit (lib.strings) fromJSON readFile;
  inherit (manifest) version;
  manifest = fromJSON (readFile ../../packs/pissfactory/bootstrap/patches/com.unascribed.unsup.json);
in
fetchurl {
  url = "https://git.sleeping.town/unascribed/unsup/releases/download/v${version}/unsup-${version}.jar";
  hash = "sha256-uxxN771PCqf8d3Vm/MFMqDdwTRsfJOOmGUZtQTk/43w=";
  passthru = {
    inherit version;
  };
}
