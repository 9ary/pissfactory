{
  description = "lightly customized monifactory build for me and my friends";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix2container = {
      url = "github:nlewo/nix2container";
      flake = false; # fuck the police
    };
  };

  outputs = inputs: let
    inherit (inputs) self;
    inherit (inputs.nixpkgs) lib;
    inherit
      (lib)
      dontRecurseIntoAttrs
      genAttrs
      ;
    forAllSystems = genAttrs systems;
    systems = lib.systems.flakeExposed;
  in {
    formatter = forAllSystems (system: let
      legacyPackages' = self.legacyPackages.${system};
      inherit (legacyPackages') nixpkgs;
    in
      nixpkgs.writeShellScriptBin "formatter" ''
        ${nixpkgs.alejandra}/bin/alejandra --quiet "''${@-.}"
      '');

    packages = forAllSystems (system: let
      legacyPackages' = self.legacyPackages.${system};
      inherit (legacyPackages') nixpkgs;
    in {
      default = legacyPackages'.pack-hardmode;
    });

    legacyPackages = forAllSystems (system: let
      nixpkgs = dontRecurseIntoAttrs (import inputs.nixpkgs {
        inherit system;
        overlays = [
          self.overlays.default
          (final: prev:
            import inputs.nix2container {
              pkgs = final;
              inherit system;
            })
        ];
      });
    in
      {inherit nixpkgs;} // nixpkgs.pissfactory);

    overlays.default = import ./overlay.nix;
  };
}
