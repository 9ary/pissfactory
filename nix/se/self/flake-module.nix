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
      config.legacyPackages.nixpkgs = pkgs;
    };
  config.systems = lib.systems.flakeExposed;
}
