{ ... }:
{
  attrPathForPackage,
  pack,
  ...
}:
pack.override {
  inherit attrPathForPackage;
  withPackMode = "expert";
}
