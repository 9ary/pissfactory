{ columns, rows, ... }:
let
  lib = rows.by-name.input.libs.default;
  mapNixpkgsPissfactoryPackages = f: lib.attrsets.mapAttrs f nixpkgsPissfactoryPackages;
  nixpkgsPissfactoryPackages = columns.nixpkgsPissfactoryPackage;
  pissfactoryLibsOverlay = rows.default.libsOverlays.default;
in
args@{
  attrPathForPackage ? null,
  generateSplicesForMkScope ? null,
  lib,
  makeScopeWithSplicing' ? null,
  newScope ? null,
  otherSplices ? null,
  splicePackages,
}:
let
  inherit (builtins) addErrorContext isNull null;
  inherit (lib.attrsets) attrByPath showAttrPath;
  inherit (lib.strings) escapeNixIdentifier;
  inherit (lib.trivial) defaultTo throwIf;
  inherit (pissfactoryLib.attrsets) defaultPackageArgTo requirePackageArg;
  inherit (pissfactoryLib.trivial) throwIfNull;

  attrPathForPackage = defaultPackageArgTo' [ "pissfactory" ] [ "attrPathForPackage" ];
  defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
  generateSplicesForMkScope = requirePackageArg' [ "generateSplicesForMkScope" ];
  makeScopeWithSplicing' = defaultPackageArgTo' (lib.customisation.makeScopeWithSplicing' {
    inherit newScope splicePackages;
  }) [ "makeScopeWithSplicing'" ];
  otherSplices = defaultPackageArgTo' (generateSplicesForMkScope attrPathForPackage) [
    "otherSplices"
  ];
  pissfactoryLib = lib.extend rows.default.libOverlay;
  requirePackageArg' = requirePackageArg args.attrPathForPackage or null args;
in
makeScopeWithSplicing' {
  inherit otherSplices;
  # TODO(<me@bb010g.com>): upstream a proper fix for this to Nixpkgs
  keep = self: {
    makeScopeWithSplicing = lib.customisation.makeScopeWithSplicing splicePackages self.newScope;
    makeScopeWithSplicing' = lib.customisation.makeScopeWithSplicing' {
      inherit splicePackages;
      inherit (self) newScope;
    };
  };
  f =
    finalPissfactory:
    let
      inherit (finalPissfactory) callPackage;
      inherit (lib)
        elemAt
        escapeShellArg
        filter
        map
        readFile
        stringLength
        substring
        ;
      inherit (lib.strings) fromJSON;
      escapeStorePath = p: escapeShellArg "${p}";
    in
    mapNixpkgsPissfactoryPackages (
      name: nixpkgsPissfactoryPackage:
      callPackage nixpkgsPissfactoryPackage { attrPathForPackage = attrPathForPackage ++ [ name ]; }
    )
    // {
      pack-lock-mods = callPackage (
        {
          pack,
          python3Packages,
          writePython3Bin ? writers.writePython3Bin,
          writers,
          ...
        }:
        writePython3Bin "lock_mods" {
          libraries =
            let
              p = python3Packages;
            in
            [
              p.requests
            ];
          makeWrapperArgs = [
            "--add-flags"
            "${pack.src}/manifest.json"
          ];
        } ../../../lock_mods.py
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack-lock-mods" ]; };

      pack-modcache = callPackage (
        { linkFarmFromDrvs, fetchurl, ... }:
        (linkFarmFromDrvs "pack-modcache" (
          map (
            mod:
            fetchurl {
              url = mod.downloadUrl;
              sha1 = (elemAt (filter (v: v.algo == 1) mod.hashes) 0).value;
            }
          ) (fromJSON (readFile ../../../mods.json))
        ))
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack-modcache" ]; };

      pack = callPackage (
        {
          # support
          applyPatches,
          fetchFromGitHub,
          importNpmLock,
          stdenvNoCC,
          # nativeBuildInputs
          jq,
          nodejs,
          packwiz,
          python3,
          unzip,
          zip,
          # mod resources
          emiPackages,
          forge-server,
          unsup,
          # arguments
          difficulty ? "normal",
          ...
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "Monifactory-${difficulty}";
          version = "0.12.6";
          # Patched source derivation allows patching npm lockfiles
          src = applyPatches {
            src = fetchFromGitHub {
              owner = "ThePansmith";
              repo = "Monifactory";
              rev = finalAttrs.version;
              hash = "sha256-sXt6dBjT2eB5iiaHM+mFkXHIXGAV03cEzVPxso38ATw=";
            };
            patches = [
              ../../../patches/0001-Add-missing-tags-to-Greg-stripped-rubber-woods.patch
              ../../../patches/0002-Avoid-duplicate-tag-tooltips.patch
              ../../../patches/0003-Enable-NBT-tooltips-by-default.patch
              ../../../patches/0004-pissfactory-rehooked-tuning.patch
              ../../../patches/0005-Restore-Thermal-s-Insightful-Condenser.patch
            ];
          };

          npmDeps = importNpmLock {
            npmRoot = "${finalAttrs.src}/tools/build";
          };

          nativeBuildInputs = [
            nodejs
            zip
            unzip
            jq
            packwiz
            python3
          ];

          postPatch = ''
            patchShebangs --build .
            rm config-overrides/*/difficultylock.json5
            cp -r --no-preserve=mode ${escapeStorePath ../../../src_overlay}/. .
            cp -r "$npmDeps"/. tools/build
          '';
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            (
              ./pack-mode-switcher.sh ${difficulty}
              cd tools/build
              export HOME="$TMPDIR"
              npm install
              node . build-client
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
              rm -r config-overrides manifest.json modlist.html

              (shopt -s extglob; eval 'cp -t mods '${escapeStorePath (escapeStorePath emiPackages.emi-unstable)}'/share/emi/emi-+([[:digit:]])*(.+([[:digit:]]))?(-SNAPSHOT)+\1.20.1\+forge.jar')

              # `packwiz init` tries to go online so we have to do this
              substitute ${escapeStorePath ../../../packwiz/pack.toml.in} pack.toml \
                --subst-var-by mc_version "$(jq -r '.minecraft.version' "$src/manifest.json")" \
                --subst-var-by forge_version "$(jq -r '.minecraft.modLoaders[0].id | sub("^forge-"; "")' "$src/manifest.json")" \
                --subst-var-by unsup_version ${escapeShellArg unsup.version}
              : > index.toml
              python3 ${escapeStorePath ../../../packwiz/gen_pw_mods.py} ${escapeStorePath ../../../mods.json}
              substitute ${escapeStorePath ../../../packwiz/forge-installer.pw.toml.in} forge-installer.pw.toml \
                --subst-var-by url ${escapeShellArg forge-server.src.url} \
                --subst-var-by hash ${escapeShellArg forge-server.src.outputHash}
              packwiz refresh
            )
            (cd ${escapeStorePath ../../../bootstrap}; zip -r "$out/pissfactory.zip" {,.}*)
            runHook postInstall
          '';
        })
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack" ]; };
      pack_hardmode = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack_hardmode" ];
        difficulty = "hardmode";
      };
      pack_expert = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack_expert" ];
        difficulty = "expert";
      };

      forge-server = callPackage (
        {
          fetchurl,
          jre,
          stdenvNoCC,
          ...
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "forge-server";
          version = "1.20.1-47.3.7";
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-kZlxL54b/PZGdrxnN3U4NrgixRKN1eqwZ4TeRKvSpYw=";

          nativeBuildInputs = [ jre ];

          src = fetchurl {
            url = "https://maven.minecraftforge.net/net/minecraftforge/forge/${finalAttrs.version}/forge-${finalAttrs.version}-installer.jar";
            # Don't change the format!
            sha256 = "efd3a04bc67f5572d6b46c73401032745f15b850afd608be7c34a32c4a81ae55";
          };

          dontUnpack = true;
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cd "$out"
            java -jar "$src" --installServer
            rm *.log
            runHook postInstall
          '';
          dontPatchShebangs = true;
        })
      ) { attrPathForPackage = attrPathForPackage ++ [ "forge-server" ]; };

      unsup = callPackage (
        { fetchurl, ... }:
        let
          manifest = fromJSON (readFile ../../../bootstrap/patches/com.unascribed.unsup.json);
          inherit (manifest) version;
        in
        fetchurl {
          url = "https://git.sleeping.town/unascribed/unsup/releases/download/v${version}/unsup-${version}.jar";
          hash = "sha256-uxxN771PCqf8d3Vm/MFMqDdwTRsfJOOmGUZtQTk/43w=";
          passthru = {
            inherit version;
          };
        }
      ) { attrPathForPackage = attrPathForPackage ++ [ "unsup" ]; };

      pack-server = callPackage (
        {
          coreutils,
          gnused,
          jre,
          unsup,
          writeShellApplication,
          ...
        }:
        writeShellApplication {
          name = "pissfactory-server";
          text = ''
            cp -f ${escapeStorePath ../../../bootstrap/minecraft/unsup.ini} unsup.ini
            java -jar ${escapeStorePath unsup} server

            if [[ forge-installer.jar -nt forge-server/.timestamp ]]; then
              rm -rf forge-server
              java -jar forge-installer.jar --installServer forge-server
              ln -sf forge-server/libraries libraries
              [[ ! -a user_jvm_args.txt ]] && cp forge-server/user_jvm_args.txt .
              touch -r forge-installer.jar forge-server/.timestamp
            fi
            if [[ ! -e forge-server/run.sh.bak ]]; then
              sed -i.bak -e '$ s/^java /exec &/' forge-server/run.sh
            fi

            if [[ -n "''${PISSFACTORY_PRODUCTION_OVERLAY-}" ]]; then
              printf '%s\n' "Declarative config overlay in use, copying $PISSFACTORY_PRODUCTION_OVERLAY over CWD!"
              cp -r "$PISSFACTORY_PRODUCTION_OVERLAY"/. .
            fi

            echo 'eula=true' > eula.txt
            # shellcheck disable=SC1091
            source ./forge-server/run.sh --nogui "$@"
          '';
          runtimeInputs = [
            coreutils
            gnused
            jre
          ];
        }
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack-server" ]; };

      pack-server-container = callPackage (
        {
          lib,
          nix2container,
          pack-server,
          runCommand,
          ...
        }:
        let
          inherit (lib.meta) getExe;
          tmp =
            runCommand "tmp"
              {
                outputHash = "sha256-AVwrjJdGCmzJ8JlT6x69JkHlFlRvOJ4hcqNt10YNoAU=";
                outputHashMode = "recursive";
                preferLocalBuild = true;
              }
              ''
                mkdir -p $out/tmp
              '';
        in
        nix2container.buildImage {
          name = "pissfactory_server";
          copyToRoot = [ tmp ];
          perms = [
            {
              path = tmp;
              regex = ".*";
              mode = "0777";
            }
          ];
          config = rec {
            entrypoint = [ (getExe pack-server) ];
            WorkingDir = "/var/lib/pissfactory";
            Env = [
              "PISSFACTORY_PRODUCTION_OVERLAY=${../../../server_cfg}"
            ];
            Volumes = {
              ${WorkingDir} = { };
            };
            ExposedPorts = {
              "25565/tcp" = { };
              "25565/udp" = { };
            };
          };
          maxLayers = 120;
        }
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack-server-container" ]; };
    };
}
