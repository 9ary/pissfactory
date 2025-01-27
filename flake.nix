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
    inherit (inputs.nixpkgs) lib;
    inherit (lib) genAttrs;
    forAllSystems = fn:
      genAttrs systems (system:
        fn rec {
          inherit system;
          pkgs = inputs.nixpkgs.legacyPackages.${system};
        });
    systems = lib.systems.flakeExposed;
  in {
    formatter = forAllSystems ({pkgs, ...}:
      pkgs.writeShellScriptBin "formatter" ''
        ${pkgs.alejandra}/bin/alejandra flake.nix
      '');

    devShells = forAllSystems ({pkgs, ...}: {
      default = pkgs.callPackage ({
        mkShell,
        curl,
        jq,
        shellcheck,
      }:
        mkShell {
          name = "pissfactory";
          packages = [curl jq shellcheck];
          env = {
            MONIFACTORY_SRC = inputs.monifactory.outPath;
          };
        }) {};
    });

    packages = forAllSystems ({pkgs, ...}: {
      modcache = pkgs.linkFarmFromDrvs "modcache" (
        builtins.map (mod:
          pkgs.fetchurl {
            url = mod.downloadUrl;
            sha1 = (builtins.elemAt (builtins.filter (v: v.algo == 1) mod.hashes) 0).value;
          }) (builtins.fromJSON (builtins.readFile ./mods.json))
      );
    });
  };
}
