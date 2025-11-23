{ ... }:
{
  fetchurl,
  jre21,
  stdenvNoCC,
  ...
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "forge-server";
  version = "1.20.1-47.3.7";
  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = "sha256-kZlxL54b/PZGdrxnN3U4NrgixRKN1eqwZ4TeRKvSpYw=";

  nativeBuildInputs = [ jre21 ];

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
