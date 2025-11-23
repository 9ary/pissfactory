{ ... }:
{
  attrPathForPackage,
  pissfactory,
  ...
}:
pissfactory.override {
  inherit attrPathForPackage;
  withPackMode = "normal";
}
