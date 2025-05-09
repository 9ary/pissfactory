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
      lockMods = callPackage (
        {
          pack,
          writers,
          writePython3Bin ? writers.writePython3Bin,
          python3Packages,
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
      ) { attrPathForPackage = attrPathForPackage ++ [ "lockMods" ]; };

      modcache = callPackage (
        { linkFarmFromDrvs, fetchurl, ... }:
        (linkFarmFromDrvs "modcache" (
          map (
            mod:
            fetchurl {
              url = mod.downloadUrl;
              sha1 = (elemAt (filter (v: v.algo == 1) mod.hashes) 0).value;
            }
          ) (fromJSON (readFile ../../../mods.json))
        ))
      ) { attrPathForPackage = attrPathForPackage ++ [ "modcache" ]; };

      pack = callPackage (
        {
          difficulty ? "normal",
          forgeServer,
          unsup,
          stdenvNoCC,
          fetchFromGitHub,
          applyPatches,
          nodejs,
          importNpmLock,
          zip,
          unzip,
          jq,
          packwiz,
          python3,
          ...
        }:
        stdenvNoCC.mkDerivation (finalAttrs: {
          pname = "Monifactory-${difficulty}";
          version = "0.11.5";
          # Patched source derivation allows patching npm lockfiles
          src = applyPatches {
            src = fetchFromGitHub {
              owner = "ThePansmith";
              repo = "Monifactory";
              rev = finalAttrs.version;
              hash = "sha256-ZcWO35/x012FO1cXe3XJ8pTxQpp2Sw4Emwtnec4da6w=";
            };
            patches = [
              ../../../patches/0001-Generate-UUIDs-deterministically.patch
              ../../../patches/0002-Add-missing-tags-to-Greg-stripped-rubber-woods.patch
              ../../../patches/0003-Avoid-duplicate-tag-tooltips.patch
              ../../../patches/0004-Enable-NBT-tooltips-by-default.patch
              ../../../patches/0005-Disable-Inventory-Tweaks-sort-in-ME-Terminal.patch
              ../../../patches/0006-pissfactory-rehooked-tuning.patch
              ../../../patches/0007-Restore-Thermal-s-Insightful-Condenser.patch
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

          env = {
            CFCORE_API_TOKEN = "dummy";
          };

          postPatch = ''
            patchShebangs --build .
            cp -r --no-preserve=mode ${escapeStorePath ../../../src_overlay}/. .
            rm config-overrides/*/difficultylock.json5
            cp -r "$npmDeps"/. tools/build
          '';
          dontConfigure = true;
          buildPhase = ''
            runHook preBuild
            (
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
              "$srcroot/pack-mode-switcher.sh" ${difficulty}
              rm -r config-overrides manifest.json modlist.html

              # `packwiz init` tries to go online so we have to do this
              substitute ${escapeStorePath ../../../packwiz/pack.toml.in} pack.toml \
                --subst-var-by mc_version "$(jq -r '.minecraft.version' "$src/manifest.json")" \
                --subst-var-by forge_version "$(jq -r '.minecraft.modLoaders[0].id | sub("^forge-"; "")' "$src/manifest.json")" \
                --subst-var-by unsup_version ${escapeShellArg unsup.version}
              : > index.toml
              python3 ${escapeStorePath ../../../packwiz/gen_pw_mods.py} ${escapeStorePath ../../../mods.json}
              substitute ${escapeStorePath ../../../packwiz/forge-installer.pw.toml.in} forge-installer.pw.toml \
                --subst-var-by url ${escapeShellArg forgeServer.src.url} \
                --subst-var-by hash ${escapeShellArg forgeServer.src.outputHash}
              packwiz refresh
            )
            (cd ${escapeStorePath ../../../bootstrap}; zip -r "$out/pissfactory.zip" {,.}*)
            runHook postInstall
          '';
        })
      ) { attrPathForPackage = attrPathForPackage ++ [ "pack" ]; };
      pack-hardmode = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack-hardmode" ];
        difficulty = "hardmode";
      };
      pack-expert = finalPissfactory.pack.override {
        attrPathForPackage = attrPathForPackage ++ [ "pack-expert" ];
        difficulty = "expert";
      };

      forgeServer = callPackage (
        {
          stdenvNoCC,
          fetchurl,
          jre,
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
      ) { attrPathForPackage = attrPathForPackage ++ [ "forgeServer" ]; };

      unsup = callPackage (
        { fetchurl, ... }:
        let
          manifest = fromJSON (readFile ../../../bootstrap/patches/com.unascribed.unsup.json);
          inherit (manifest) version;
        in
        fetchurl {
          url = "https://git.sleeping.town/unascribed/unsup/releases/download/v${version}/unsup-${version}.jar";
          hash = "sha256-DU0DKqzfuE6p4whFkSbQcHJJGvfA75eDg3jnzsHGlnI=";
          passthru = {
            inherit version;
          };
        }
      ) { attrPathForPackage = attrPathForPackage ++ [ "unsup" ]; };

      runServer = callPackage (
        {
          writeShellApplication,
          coreutils,
          gnused,
          jre,
          unsup,
          ...
        }:
        writeShellApplication {
          name = "pissfactory_server";
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
      ) { attrPathForPackage = attrPathForPackage ++ [ "runServer" ]; };

      container = callPackage (
        {
          nix2container,
          runCommand,
          runServer,
          ...
        }:
        let
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
            entrypoint = [ "${runServer}/bin/${runServer.name}" ];
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
      ) { attrPathForPackage = attrPathForPackage ++ [ "container" ]; };
    };
}
