{ columns, ... }:
{ config, lib, ... }:
let
  rootConfig = config;
  nixpkgsOverlays = config.flake.overlays;
in
{
  config.flake.flakeModules = columns.flakeModule;
  config.flake.overlays = columns.nixpkgsOverlay;
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
      config.packages.default = pkgs.pissfactory.pack-hardmode;
      config.legacyPackages =
        let
          inherit (lib.lists) all;
          inherit (lib.attrsets) attrNames attrValues intersectAttrs isDerivation removeAttrs;
          pissfactoryLegacyPackages = removeAttrs pkgs.pissfactory [
            "callPackage"
            "newScope"
            "override"
            "overrideDerivation"
            "overrideScope"
            "packages"
          ];
          extraLegacyPackages = {
            nixpkgs = pkgs;
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
