{ ... }:
{
  coreutils,
  gnused,
  jre21,
  lib,
  unsup_pissfactory,
  writeShellApplication,
  ...
}:
let
  inherit (lib.strings) escapeShellArg;
  escapeStorePath = p: escapeShellArg "${p}";
in
writeShellApplication {
  name = "pissfactory-server";
  text = ''
    cp -f ${escapeStorePath ../../packs/pissfactory/bootstrap/minecraft/unsup.ini} unsup.ini
    java -jar ${escapeStorePath unsup_pissfactory} server

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
    jre21
  ];
}
