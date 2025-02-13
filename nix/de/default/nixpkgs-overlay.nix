{ columns, rows, ... }:
let
  mapNixpkgsPackages = f: lib.attrsets.mapAttrs f nixpkgsPackages;
  nixpkgsPackages = columns.nixpkgsPackage;
  lib = rows.by-name.input.libs.default;
in
finalPkgs: prevPkgs:
let
  inherit (finalPkgs) callPackage;
in
mapNixpkgsPackages (name: nixpkgsPackage: callPackage nixpkgsPackage { })
