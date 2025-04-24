{ ... }:
{
  stdenv,
  jdk21_headless,
  lib,
  callPackage,
}:
let
  jdk = jdk21_headless;
in
stdenv.mkDerivation {
  pname = "${jdk.pname}-minimal-jre";
  version = jdk.version;

  buildInputs = [ jdk ];

  dontUnpack = true;

  # Strip more heavily than the default '-S', since if you're
  # using this derivation you probably care about this.
  stripDebugFlags = [ "--strip-unneeded" ];

  buildPhase = ''
    runHook preBuild

    mkdir modpath
    ln -s ${jdk}/lib/openjdk/jmods/* modpath
    # jpackage includes path references to the base JDK in some native binaries
    rm modpath/jdk.jpackage.jmod
    jlink --module-path modpath --add-modules ALL-MODULE-PATH --compress=2 --output $out

    runHook postBuild
  '';

  dontInstall = true;
}
