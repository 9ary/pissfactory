{ ... }:
{
  attrPathForPackage,
  pack,
  ...
}:
pack.override {
  inherit attrPathForPackage;
  withPackMode = "hardmode";
}
