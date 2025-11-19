{ columns, ... }:
{ config, lib, ... }:
let
  rootConfig = config;
  nixpkgsOverlays = config.flake.overlays;
  pissfactoryLib = config.flake.libs.default;
in
{
  config.flake.flakeModules = columns.flakeModule;
  config.flake.overlays = columns.nixpkgsOverlay;
  config.flake.libOverlays = columns.libOverlay;
  config.flake.libs = lib.attrsets.mapAttrs (
    libName: libOverlay: lib.extend libOverlay
  ) rootConfig.flake.libOverlays;
  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      config._module.args.pkgs = import columns.input.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [ nixpkgsOverlays.self ];
      };
      config.formatter = pkgs.callPackage (
        {
          nixfmt-rfc-style,
          treefmt,
          writeShellApplication,
        }:
        writeShellApplication {
          name = "formatter";
          text = ''
            treefmt "''${@-.}"
          '';
          runtimeInputs = [
            nixfmt-rfc-style
            treefmt
          ];
        }
      ) { };
      config.checks =
        let
          inherit (lib.attrsets)
            concatMapAttrsToList
            isDerivation
            listToAttrs
            mapAttrs
            recurseIntoAttrs
            ;
          inherit (lib.lists) concatMap;
          inherit (lib.strings) escapeNixIdentifier;
          inherit (lib.trivial) isNull null;
          flattenDerivationsToList =
            namePrefix: attrs:
            concatMapAttrsToList (
              unescapedName: value:
              let
                name =
                  let
                    escapedName = escapeNixIdentifier unescapedName;
                  in
                  if isNull namePrefix then escapedName else "${namePrefix}.${escapedName}";
              in
              if isDerivation value then
                [ { inherit name value; } ]
              else if shouldRecurseIntoAttrs value then
                flattenDerivationsToList name value
              else
                [ ]
            ) attrs;
          flattenDerivations = namePrefix: attrs: listToAttrs (flattenDerivationsToList namePrefix attrs);
          lib = pissfactoryLib;
          shouldRecurseIntoAttrs = value: value.recurseForDerivations or false;
        in
        flattenDerivations null (
          mapAttrs (name: attrs: recurseIntoAttrs attrs) {
            inherit (config) devShells legacyPackages packages;
          }
        );
      config.devShells.default = pkgs.callPackage (
        {
          nixfmt-rfc-style,
          mkShellNoCC,
          treefmt,
        }:
        mkShellNoCC {
          nativeBuildInputs = [
            nixfmt-rfc-style
            treefmt
          ];
        }
      ) { };
      config.packages.default = pkgs.pissfactory.minecraft-site-static-root;
      config.legacyPackages =
        let
          inherit (lib.lists) all;
          inherit (lib.attrsets)
            attrNames
            attrValues
            dontRecurseIntoAttrs
            intersectAttrs
            isDerivation
            removeAttrs
            ;
          pissfactoryLegacyPackages = removeAttrs pkgs.pissfactory [
            "callPackage"
            "newScope"
            "override"
            "overrideDerivation"
            "overrideScope"
            "packages"
          ];
          extraLegacyPackages = {
            nixpkgs = dontRecurseIntoAttrs pkgs;
          };
          overriddenPissfactoryLegacyPackages = intersectAttrs extraLegacyPackages pissfactoryLegacyPackages;
          overriddenPissfactoryLegacyPackageNames = attrNames overriddenPissfactoryLegacyPackages;
        in
        assert all isDerivation (attrValues pissfactoryLegacyPackages);
        assert overriddenPissfactoryLegacyPackageNames == [ ];
        pissfactoryLegacyPackages // extraLegacyPackages;
    };
  config.systems = lib.systems.flakeExposed;
}
