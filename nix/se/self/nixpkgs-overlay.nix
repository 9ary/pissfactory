{ rows, ... }:
let
  lib = rows.by-name.input.libs.default;
in
lib.fixedPoints.composeManyExtensions [
  rows.nix2container.nixpkgsOverlay
  rows.default.nixpkgsOverlay
]
