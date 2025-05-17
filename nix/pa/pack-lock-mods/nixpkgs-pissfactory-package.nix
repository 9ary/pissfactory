{ ... }:
{
  pack,
  python3Packages,
  writePython3Bin ? writers.writePython3Bin,
  writers,
  ...
}:
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
} ../../../lock_mods.py
