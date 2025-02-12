final: prev:
let
  inherit (final) callPackage lib;
  inherit (lib) recurseIntoAttrs;
in
{
  pissfactory = recurseIntoAttrs (callPackage ./packages.nix { });
}
