{ columns, rows, ... }:
let
  mapNixpkgsPissfactoryPackages =
    let
      inherit (lib.attrsets) mapAttrs;
      lib = rows.by-name.input.libs.default;
    in
    f: mapAttrs f nixpkgsPissfactoryPackages;
  nixpkgsPissfactoryPackages = columns.nixpkgsPissfactoryPackage;
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
  inherit (pissfactoryLib.attrsets) defaultPackageArgTo requirePackageArg;
  inherit (pissfactoryLib.trivial) throwIfNull;

  attrPathForPackage = defaultPackageArgTo' [ "pissfactory" ] [ "attrPathForPackage" ];
  defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
  generateSplicesForMkScope = requirePackageArg' [ "generateSplicesForMkScope" ];
  makeScopeWithSplicing' = defaultPackageArgTo' (lib.customisation.makeScopeWithSplicing' {
    inherit newScope splicePackages;
  }) [ "makeScopeWithSplicing'" ];
  otherSplices = defaultPackageArgTo' (generateSplicesForMkScope attrPathForPackage) [
    "otherSplices"
  ];
  pissfactoryLib = lib.extend rows.default.libOverlay;
  requirePackageArg' = requirePackageArg args.attrPathForPackage or null args;
in
makeScopeWithSplicing' {
  inherit otherSplices;
  extra = splicedPissfactory: {
    lib = pissfactoryLib;
  };
  # TODO(<me@bb010g.com>): upstream a proper fix for this to Nixpkgs
  keep = self: {
    makeScopeWithSplicing = lib.customisation.makeScopeWithSplicing splicePackages self.newScope;
    makeScopeWithSplicing' = lib.customisation.makeScopeWithSplicing' {
      inherit splicePackages;
      inherit (self) newScope;
    };
  };
  f =
    finalPissfactory:
    let
      inherit (finalPissfactory) callPackage;
    in
    mapNixpkgsPissfactoryPackages (
      name: nixpkgsPissfactoryPackage:
      callPackage nixpkgsPissfactoryPackage { attrPathForPackage = attrPathForPackage ++ [ name ]; }
    )
    // {
      pack_hardmode = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack_hardmode" ];
        difficulty = "hardmode";
      };
      pack_expert = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack_expert" ];
        difficulty = "expert";
      };
    };
}
