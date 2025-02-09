{
  stdenv,
  jdk17_headless,
  lib,
  callPackage,
}: let
  jdk = jdk17_headless;
in
  stdenv.mkDerivation {
    pname = "${jdk.pname}-minimal-jre";
    version = jdk.version;

    buildInputs = [jdk];

    dontUnpack = true;

    # Strip more heavily than the default '-S', since if you're
    # using this derivation you probably care about this.
    stripDebugFlags = ["--strip-unneeded"];

    buildPhase = ''
      runHook preBuild

      mkdir modpath
      ln -s ${jdk}/lib/openjdk/jmods/* modpath
      # jpackage includes path references to the base JDK in some native binaries
      rm modpath/jdk.jpackage.jmod
      # Additional size reduction
      rm modpath/jdk.hotspot.agent.jmod
      rm modpath/jdk.localedata.jmod
      rm modpath/{jdk.*compiler*,jdk.jdeps,jdk.jlink,jdk.jshell,jdk.javadoc}.jmod
      rm modpath/jdk.charsets.jmod
      rm modpath/jdk.incubator.*.jmod
      jlink --module-path modpath --add-modules ALL-MODULE-PATH --compress=2 --output $out

      runHook postBuild
    '';

    dontInstall = true;
  }
