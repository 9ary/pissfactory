{ ... }:
{
  linkFarm,
  pack_hardmode,
  symlinkJoin,
  ...
}:
let
  minecraft-site-static-pack =
    { name, minecraft }:
    linkFarm "minecraft-site-static-pack-${name}" [
      {
        name = "packs/${name}/minecraft";
        path = minecraft;
      }
    ];
in
symlinkJoin {
  name = "minecraft-site-static-root";
  paths = [
    pack_hardmode
    (minecraft-site-static-pack {
      name = "pissfactory";
      minecraft = pack_hardmode;
    })
  ];
}
