{ columns, rows, ... }:
let
  mapNixpkgsCatgirlVPackages =
    let
      inherit (lib.attrsets) mapAttrs;
      lib = rows.by-name.input.libs.default;
    in
    f: mapAttrs f nixpkgsCatgirlVPackages;
  nixpkgsCatgirlVPackages = columns.nixpkgsCatgirlVPackage;
in
args@{
  attrPathForPackage ? null,
  generateSplicesForMkScope ? null,
  lib,
  makeScopeWithSplicing' ? null,
  newScope ? null,
  otherSplices ? null,
  splicePackages,
}:
let
  inherit (builtins) addErrorContext isNull null;
  inherit (lib.attrsets) attrByPath showAttrPath;
  inherit (lib.strings) escapeNixIdentifier;
  inherit (lib.trivial) defaultTo throwIf;
  inherit (catgirlVLib.attrsets) defaultPackageArgTo requirePackageArg;
  inherit (catgirlVLib.trivial) throwIfNull;

  attrPathForPackage = defaultPackageArgTo' [ "catgirlV" ] [ "attrPathForPackage" ];
  defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
  generateSplicesForMkScope = requirePackageArg' [ "generateSplicesForMkScope" ];
  makeScopeWithSplicing' = defaultPackageArgTo' (lib.customisation.makeScopeWithSplicing' {
    inherit newScope splicePackages;
  }) [ "makeScopeWithSplicing'" ];
  otherSplices = defaultPackageArgTo' (generateSplicesForMkScope attrPathForPackage) [
    "otherSplices"
  ];
  catgirlVLib = lib.extend rows.default.libOverlay;
  requirePackageArg' = requirePackageArg args.attrPathForPackage or null args;
in
makeScopeWithSplicing' {
  inherit otherSplices;
  extra = splicedCatgirlV: {
    lib = catgirlVLib;
  };
  # TODO(<me@bb010g.com>): upstream a proper fix for this to Nixpkgs
  keep = finalCatgirlV: {
    makeScopeWithSplicing = lib.customisation.makeScopeWithSplicing splicePackages finalCatgirlV.newScope;
    makeScopeWithSplicing' = lib.customisation.makeScopeWithSplicing' {
      inherit splicePackages;
      inherit (finalCatgirlV) newScope;
    };
  };
  f =
    finalCatgirlV:
    let
      inherit (finalCatgirlV) callPackage;
    in
    mapNixpkgsCatgirlVPackages (
      name: nixpkgsCatgirlVPackage:
      callPackage nixpkgsCatgirlVPackage { attrPathForPackage = attrPathForPackage ++ [ name ]; }
    );
}
