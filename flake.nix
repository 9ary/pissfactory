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
        python3,
      }:
        mkShell {
          name = "pissfactory";
          packages = [curl jq shellcheck python3];
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

      pack = pkgs.callPackage ({
        difficulty ? "normal",
        stdenvNoCC,
        nodejs,
        zip,
        unzip,
        jq,
        packwiz,
        python3,
      }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          name = "Monifactory-${difficulty}";
          src = inputs.monifactory;

          nativeBuildInputs = [nodejs zip unzip jq packwiz python3];

          env = {
            CFCORE_API_TOKEN = "dummy";
          };

          postPatch = ''
            patchShebangs --build .
            cp -r '${./overlay}/.' .
            rm config-overrides/*/difficultylock.json5
          '';
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            (
              cd tools/build
              node build.js -c build-client
            )
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            unzip dist/client.zip -d "$out"
            (
              srcroot=$PWD
              cd "$out"
              (shopt -s dotglob; mv overrides/* .)
              rmdir overrides
              "$srcroot/pack-mode-switcher.sh" ${difficulty}
              rm -r config-overrides manifest.json modlist.html

              # `packwiz init` tries to go online so we have to do this
              substitute '${./pack.toml.in}' pack.toml \
                --subst-var-by mc_version "$(jq -r '.minecraft.version' "$src/manifest.json")" \
                --subst-var-by forge_version "$(jq -r '.minecraft.modLoaders[0].id | sub("^forge-"; "")' "$src/manifest.json")"
              : > index.toml
              python3 '${./gen_pw_mods.py}' '${./mods.json}'
              packwiz refresh
            )
            (cd '${./bootstrap}'; zip -r "$out/pissfactory.zip" {,.}*)
            runHook postInstall
          '';
        })) {};
      pack-hardmode = packages.pack.override {difficulty = "hardmode";};
      pack-expert = packages.pack.override {difficulty = "expert";};
      default = packages.pack-hardmode;
    });
  };
}
