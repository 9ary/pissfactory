{
  description = "lightly customized monifactory build for me and my friends";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container = {
      url = "github:nlewo/nix2container";
      flake = false; # fuck the police
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs) self;
      inherit (inputs.nixpkgs) lib;
      inherit (lib) dontRecurseIntoAttrs genAttrs;
      forAllSystems = genAttrs systems;
      systems = lib.systems.flakeExposed;
    in
    {
      devShells = forAllSystems (
        system:
        let
          formatter' = self.formatter.${system};
          legacyPackages' = self.legacyPackages.${system};
          inherit (legacyPackages') nixpkgs;
        in
        {
          default = nixpkgs.callPackage (
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
        }
      );

      formatter = forAllSystems (
        system:
        let
          legacyPackages' = self.legacyPackages.${system};
          inherit (legacyPackages') nixpkgs;
        in
        nixpkgs.callPackage (
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
        ) { }
      );

      packages = forAllSystems (
        system:
        let
          legacyPackages' = self.legacyPackages.${system};
          inherit (legacyPackages') nixpkgs;
        in
        {
          default = legacyPackages'.pack-hardmode;
        }
      );

      legacyPackages = forAllSystems (
        system:
        let
          nixpkgs = dontRecurseIntoAttrs (
            import inputs.nixpkgs {
              inherit system;
              overlays = [
                self.overlays.default
                (
                  final: prev:
                  import inputs.nix2container {
                    pkgs = final;
                    inherit system;
                  }
                )
              ];
            }
          );
        in
        { inherit nixpkgs; } // nixpkgs.pissfactory
      );

      overlays.default = import ./overlay.nix;
    };
}
