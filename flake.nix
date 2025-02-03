{
  description = "lightly customized monifactory build for me and my friends";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    monifactory = {
      url = "github:ThePansmith/Monifactory/0.11.3";
      flake = false;
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
        ${nixpkgs.alejandra}/bin/alejandra .
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
        ];
      });
    in
      {inherit nixpkgs;} // nixpkgs.pissfactory);

    overlays.default = import ./overlay.nix inputs;
  };
}
