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
          packages = inputs.self.packages.${system};
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

    packages = forAllSystems ({
      pkgs,
      packages,
      ...
    }: {
      modcache = pkgs.linkFarmFromDrvs "modcache" (
        builtins.map (mod:
          pkgs.fetchurl {
            url = mod.downloadUrl;
            sha1 = (builtins.elemAt (builtins.filter (v: v.algo == 1) mod.hashes) 0).value;
          }) (builtins.fromJSON (builtins.readFile ./mods.json))
      );

      modpack = pkgs.callPackage ({
        stdenvNoCC,
        nodejs,
        zip,
      }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          name = "Monifactory";
          src = inputs.monifactory;
          patches = [
            ./patches/0001-Build-offline.patch
            ./patches/0002-Fix-shebangs.patch
            ./patches/0003-Build-fat-client-zip.patch
            ./patches/0004-Exclude-Ears-and-Speedometer-from-server-pack.patch
          ];

          nativeBuildInputs = [nodejs zip];

          postPatch = ''
            mkdir -p dist
            patchShebangs --build tools
            cp -r '${./overlay}/.' .
            ln -s '${packages.modcache}' dist/modcache
          '';
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            (
              cd tools/build
              node build.js -c build-all
            )
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp dist/{client,server}.zip "$out"
            runHook postInstall
          '';
        })) {};
    });
  };
}
