{ ... }:
{
  attrPathForPackage,
  pissfactory,
  ...
}:
pissfactory.override {
  inherit attrPathForPackage;
  withPackMode = "expert";
}
