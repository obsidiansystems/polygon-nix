{ pkgs ? import ./dep/nixpkgs {}
, lib ? pkgs.lib
}:

lib.makeScope pkgs.newScope (self: {
  bor = self.callPackage ./bor {
    inherit (pkgs.darwin) libobjc;
    inherit (pkgs.darwin.apple_sdk.frameworks) IOKit;
  };
})
