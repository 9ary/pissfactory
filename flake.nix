{
  description = "lightly customized monifactory build for me and my friends";

  inputs.by-name.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.by-name.url = "github:bb010g/by-name.nix";
  inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";
  inputs.nix2container.flake = false; # fuck the police
  inputs.nix2container.url = "github:nlewo/nix2container";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
      table = lib.filesystem.readNameBasedTableDirectory {
        rowFromFile."flake-module.nix" = table: { flakeModule = importModuleCell table; };
        rowFromFile."nixpkgs-overlay.nix" = table: { nixpkgsOverlay = importCell table; };
        rowFromFile."nixpkgs-package.nix" = table: { nixpkgsPackage = importCell table; };
        rowFromFile."nixpkgs-pissfactory-package.nix" = table: {
          nixpkgsPissfactoryPackage = importCell table;
        };
        rowsPath = ./nix;
        specialColumns.input = inputs;
      };
    in
    inputs.flake-parts.lib.mkFlake {
      inherit inputs;
      moduleLocation = ./flake.nix;
    } table.rows.self.flakeModule;
}
