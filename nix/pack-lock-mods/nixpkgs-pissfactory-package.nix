{ ... }:
args@{
  lib,
  pack,
  python3Packages,
  writePython3Bin ? null,
  writers,
  ...
}:
let
  inherit (lib.attrsets) defaultPackageArgTo;
  defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
  writePython3Bin = defaultPackageArgTo' writers.writePython3Bin [ "writePython3Bin" ];
in
writePython3Bin "lock_mods" {
  libraries =
    let
      p = python3Packages;
    in
    [
      p.requests
    ];
  makeWrapperArgs = [
    "--add-flags"
    "${pack.src}/manifest.json"
  ];
} ../../lock_mods.py
