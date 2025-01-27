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

      client = pkgs.callPackage ({
        side ? "client",
        difficulty ? "normal",
        stdenvNoCC,
        nodejs,
        zip,
        unzip,
      }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          name = "Monifactory-${side}-${difficulty}";
          src = inputs.monifactory;

          nativeBuildInputs = [nodejs zip unzip];

          env = {
            CFCORE_API_TOKEN = "dummy";
          };

          postPatch =
            ''
              patchShebangs --build .
              cp -r '${./overlay}/.' .
              mkdir -p dist/modcache
              cp -r --preserve=links '${packages.modcache}/.' dist/modcache
            ''
            + (lib.optionalString (side == "server") ''
              rm dist/modcache/{ears-forge-*.jar,giacomos_speedometer-*.jar}
            '');
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            (
              cd tools/build
              node build.js -c build-${side}
            )
            runHook postBuild
          '';
          installPhase =
            ''
              runHook preInstall
              mkdir -p "$out"
              unzip dist/${side}.zip -d "$out"
            ''
            + (lib.optionalString (side == "client") ''
              cp -Lr dist/modcache/. "$out/overrides/mods"
            '')
            + ''
              (
                srcroot=$PWD
                cd "$out/overrides"
                "$srcroot/pack-mode-switcher.sh" ${difficulty}
              )
              runHook postInstall
            '';
        })) {};
      server = packages.client.override {side = "server";};
      both = pkgs.linkFarmFromDrvs "Monifactory" [packages.client packages.server];

      client-hardmode = packages.client.override {difficulty = "hardmode";};
      server-hardmode = packages.server.override {difficulty = "hardmode";};
      both-hardmode = pkgs.linkFarmFromDrvs "Monifactory-hardmode" [packages.client-hardmode packages.server-hardmode];

      client-expert = packages.client.override {difficulty = "expert";};
      server-expert = packages.server.override {difficulty = "expert";};
      both-expert = pkgs.linkFarmFromDrvs "Monifactory-expert" [packages.client-expert packages.server-expert];

      default = packages.both-hardmode;
    });
  };
}
