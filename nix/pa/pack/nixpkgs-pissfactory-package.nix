{ ... }:
args@{
  # support
  applyPatches,
  fetchFromGitHub,
  importNpmLock,
  lib,
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
  difficulty ? null,
  ...
}:
let
  inherit (lib.attrsets) defaultPackageArgTo;
  inherit (lib.strings) escapeShellArg;
  defaultPackageArgTo' = defaultPackageArgTo args.attrPathForPackage or null args;
  difficulty = defaultPackageArgTo' "normal" [ "difficulty" ];
  escapeStorePath = p: escapeShellArg "${p}";
in
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
