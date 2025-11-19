{ ... }:
{
  buildEnv,
  lib,
  linkFarm,
  pack_hardmode,
  runCommand,
  zip,
  ...
}:
let
  inherit (lib.strings) escapeShellArg;
  escapeStorePath = p: escapeShellArg "${p}";

  singletonLinkFarm =
    name: name': path:
    linkFarm name [
      {
        inherit path;
        name = name';
      }
    ];

  minecraft-site-static-pack =
    {
      bootstrap,
      minecraft,
      name,
    }:
    let
      bootstrap-zip =
        runCommand "${name}-bootstrap-zip"
          {
            nativeBuildInputs = [ zip ];
          }
          ''
            cd ${escapeStorePath bootstrap}
            mkdir -p -- "$out"
            zip -r "$out/"${escapeShellArg name}'.zip' -- {,.}*
          '';
      minecraft' = singletonLinkFarm "${name}-minecraft" "minecraft" minecraft;
    in
    buildEnv {
      name = "minecraft-site-static-pack-${name}";
      paths = [
        bootstrap-zip
        minecraft'
      ];
    };

  minecraft-site-static-root-pack =
    args:
    singletonLinkFarm "minecraft-site-static-root-pack-${args.name}" "packs/${args.name}" (
      minecraft-site-static-pack args
    );
in
buildEnv {
  name = "minecraft-site-static-root";
  paths = [
    pack_hardmode
    (minecraft-site-static-root-pack {
      bootstrap = pack_hardmode.bootstrap;
      minecraft = pack_hardmode;
      name = "pissfactory";
    })
  ];
}
