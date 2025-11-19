{ ... }:
{
  pack_hardmode,
  symlinkJoin,
  ...
}:
symlinkJoin {
  name = "minecraft-site-static-root";
  paths = [
    pack_hardmode
  ];
}
