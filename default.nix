{ pkgs ? import ./dep/nixpkgs {}
, lib ? pkgs.lib
, network ? "mainnet"
}:

lib.makeScope pkgs.newScope (self: {
  bor = self.callPackage ./bor {
    inherit (pkgs.darwin) libobjc;
    inherit (pkgs.darwin.apple_sdk.frameworks) IOKit;
  };
  heimdall = self.callPackage ./heimdall {
    network = network;
  };
})
