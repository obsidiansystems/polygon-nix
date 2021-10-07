{ pkgs ? import ./dep/nixpkgs {}
, lib ? pkgs.lib
, network ? "mainnet"
}:
let

  nixpkgs2003 = import (builtins.fetchTarball {
    name = "nixpkgs-20.03";
    url = "https://github.com/nixos/nixpkgs/archive/eb73405ecceb1dc505b7cbbd234f8f94165e2696.tar.gz";
    sha256 = "06k21wbyhhvq2f1xczszh3c2934p0m02by3l2ixvd6nkwrqklax7";
  }) {};

  borChainIds = {
    mainnet = "137";
    mumbai = "80001";
    local = "15001";
  };

in lib.makeScope pkgs.newScope (self: {
  bor = self.callPackage ./bor {
    inherit (pkgs.darwin) libobjc;
    inherit (pkgs.darwin.apple_sdk.frameworks) IOKit;
  };
  heimdall = self.callPackage ./heimdall {
    network = network;
  };
  matic-cli = self.callPackage ./matic-cli {
    nodejs = pkgs.nodejs-10_x;
    inherit pkgs;
  };
  matic-cli-shell = pkgs.mkShell {
    packages = [
      nixpkgs2003.solc # Need solc 0.5
      pkgs.cacert # For SSL certs so we can clone https
      pkgs.git
      pkgs.go
      pkgs.python3
      pkgs.docker
      pkgs.docker-compose
      self.matic-cli.package
    ];
  };
})
