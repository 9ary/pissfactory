{ ... }:
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
