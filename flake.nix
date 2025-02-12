{
  description = "lightly customized monifactory build for me and my friends";

  inputs = {
    by-name.inputs.nixpkgs-lib.follows = "nixpkgs";
    by-name.url = "github:bb010g/by-name.nix";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix2container.flake = false; # fuck the police
    nix2container.url = "github:nlewo/nix2container";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    let
      inherit (lib.modules) setDefaultModuleLocation;
      importCell = table@{ directoryEntry, ... }: import directoryEntry.path table;
      importModuleCell =
        table@{ directoryEntry, ... }:
        let
          inherit (directoryEntry) path;
        in
        setDefaultModuleLocation path (import path table);
      lib = inputs.by-name.libs.default;
      pissfactoryLib = lib.extend table.rows.default.libOverlay;
      table = lib.filesystem.readNameBasedTableDirectory {
        rowFromFile."flake-module.nix" = table: { flakeModule = importModuleCell table; };
        rowFromFile."lib-overlay.nix" = table: { libOverlay = importCell table; };
        rowFromFile."nixpkgs-overlay.nix" = table: { nixpkgsOverlay = importCell table; };
        rowFromFile."nixpkgs-package.nix" = table: { nixpkgsPackage = importCell table; };
        rowFromFile."nixpkgs-pissfactory-package.nix" = table: {
          nixpkgsPissfactoryPackage = importCell table;
        };
        rowsPath = ./nix;
        specialColumns.input = inputs;
        specialColumns.lib.default = pissfactoryLib;
      };
    in
    inputs.flake-parts.lib.mkFlake {
      inherit inputs;
      moduleLocation = ./flake.nix;
    } table.rows.self.flakeModule;
}
