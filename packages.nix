{ lib, newScope }:
lib.makeScope newScope (
  self:
  let
    inherit (self) callPackage;
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
  {
    lockMods = callPackage (
      {
        pack,
        writeShellApplication,
        curl,
        jq,
      }:
      writeShellApplication {
        name = "lock_mods";
        text = ''
          if [[ -z "''${CFCORE_API_TOKEN+x}" ]]; then
            # shellcheck disable=SC2016
            printf '%s\n' 'Please set $CFCORE_API_TOKEN (https://console.curseforge.com/#/api-keys)'
            exit 1
          fi

          curl 'https://api.curseforge.com/v1/mods/files' \
            --header "X-Api-Key: $CFCORE_API_TOKEN" \
            --header 'Content-Type: application/json' \
            --data "$(jq -n '{"fileIds": [inputs.files[].fileID]}' ${escapeStorePath pack.src}/manifest.json ${escapeStorePath ./manifest_extras.json})" \
            | jq '.data | unique | sort_by(.modId) | map(.downloadUrl = (.downloadUrl // "https://edge.forgecdn.net/files/\(.id / 1000 | trunc)/\(.id % 1000)/\(.fileName)")) | map(del(.downloadCount, .gameVersions, .sortableGameVersions))' \
            > mods.json
        '';
        runtimeInputs = [
          curl
          jq
        ];
      }
    ) { };

    modcache = callPackage (
      { linkFarmFromDrvs, fetchurl }:
      (linkFarmFromDrvs "modcache" (
        map (
          mod:
          fetchurl {
            url = mod.downloadUrl;
            sha1 = (elemAt (filter (v: v.algo == 1) mod.hashes) 0).value;
          }
        ) (fromJSON (readFile ./mods.json))
      ))
    ) { };

    pack = callPackage (
      {
        difficulty ? "normal",
        forgeServer,
        stdenvNoCC,
        fetchFromGitHub,
        nodejs,
        zip,
        unzip,
        jq,
        packwiz,
        python3,
      }:
      stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "Monifactory-${difficulty}";
        version = "0.11.3";
        src = fetchFromGitHub {
          owner = "ThePansmith";
          repo = "Monifactory";
          rev = finalAttrs.version;
          hash = "sha256-belpDJ1VYqQwMtFWSgJFc/TTSkAslOH/kKgFm27t6A0=";
        };
        patches = [ ./patches/0001-Generate-UUIDs-deterministically.patch ];

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
          cp -r ${escapeStorePath ./src_overlay}/. .
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
            substitute ${escapeStorePath ./packwiz/pack.toml.in} pack.toml \
              --subst-var-by mc_version "$(jq -r '.minecraft.version' "$src/manifest.json")" \
              --subst-var-by forge_version "$(jq -r '.minecraft.modLoaders[0].id | sub("^forge-"; "")' "$src/manifest.json")"
            : > index.toml
            python3 ${escapeStorePath ./packwiz/gen_pw_mods.py} ${escapeStorePath ./mods.json}
            substitute ${escapeStorePath ./packwiz/forge-installer.pw.toml.in} forge-installer.pw.toml \
              --subst-var-by url ${escapeShellArg forgeServer.src.url} \
              --subst-var-by hash ${escapeShellArg forgeServer.src.outputHash}
            packwiz refresh
          )
          (cd ${escapeStorePath ./bootstrap}; zip -r "$out/pissfactory.zip" {,.}*)
          runHook postInstall
        '';
      })
    ) { };
    pack-hardmode = self.pack.override { difficulty = "hardmode"; };
    pack-expert = self.pack.override { difficulty = "expert"; };

    jre = callPackage ./jre.nix { };

    forgeServer = callPackage (
      {
        stdenvNoCC,
        fetchurl,
        jre,
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
    ) { };

    unsup = callPackage (
      { fetchurl }:
      fetchurl (
        let
          version = "1.0-rc2";
        in
        {
          url = "https://git.sleeping.town/unascribed/unsup/releases/download/v${version}/unsup-${version}.jar";
          hash = "sha256-h+SpjMvvpGAlHO1YY+mPqoyrvxoDX0CoKl+9jA3L9fw=";
        }
      )
    ) { };

    runServer = callPackage (
      {
        writeShellApplication,
        coreutils,
        jre,
        unsup,
      }:
      writeShellApplication {
        name = "pissfactory_server";
        text = ''
          cp -f ${escapeStorePath ./bootstrap/minecraft/unsup.ini} unsup.ini
          java -jar ${escapeStorePath unsup} server

          if [[ forge-installer.jar -nt forge-server/.timestamp ]]; then
            rm -rf forge-server
            java -jar forge-installer.jar --installServer forge-server
            ln -sf forge-server/libraries libraries
            [[ ! -a user_jvm_args.txt ]] && cp forge-server/user_jvm_args.txt .
            touch -r forge-installer.jar forge-server/.timestamp
          fi

          echo 'eula=true' > eula.txt
          # shellcheck disable=SC1091
          source ./forge-server/run.sh --nogui "$@"
        '';
        runtimeInputs = [
          coreutils
          jre
        ];
      }
    ) { };

    container = callPackage (
      {
        nix2container,
        runCommand,
        runServer,
      }:
      let
        tmp = runCommand "tmp" { } ''
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
    ) { };
  }
)
