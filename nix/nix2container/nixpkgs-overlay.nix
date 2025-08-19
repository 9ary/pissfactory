{ rows, ... }:
finalPkgs: prevPkgs:
import rows.nix2container.input {
  pkgs = finalPkgs;
  # whether this should be from `buildPlatform` (`localSystem`) or `hostPlatform` (`crossSystem`) is ambiguous
  system = finalPkgs.buildPlatform.system;
}
