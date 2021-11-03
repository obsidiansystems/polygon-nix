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

  launchSrc = pkgs.fetchFromGitHub {
    owner = "maticnetwork";
    repo = "launch";
    rev = "e94da85c31a4334dfd4b11c93b428060e9cf9307";
    sha256 = "1fm1xvs7spfkpfkrmrfiqfh5za45sy9kj4z4qkxax2w86yzifn1n";
  };

in lib.makeScope pkgs.newScope (self: rec {
  launch-src = launchSrc;
  bor = self.callPackage ./bor {
    inherit (pkgs.darwin) libobjc;
    inherit (pkgs.darwin.apple_sdk.frameworks) IOKit;
  };
  heimdall = self.callPackage ./heimdall {
    network = network;
  };
  # Patched heimdall testnet files
  heimdall-testnet = {
    p2p_laddr_port ? 26656,
    rpc_laddr_port ? 26657,
    proxy_app_port ? 26658,
    prof_laddr_port ? 6060,
    eth_rpc_url ? "http://localhost:9545",
    bor_rpc_url ? "http://localhost:8545",
    heimdall_rest_server_port ? 1317,
  }: pkgs.stdenv.mkDerivation {
    name = "heimdall-testnet";
    src = launchSrc;
    buildInputs = [ heimdall.gopkg ];
    # TODO AMQP endpoint? 5672
    buildPhase = ''
      NETWORK=./testnet-v4
      LAUNCH_NODE_DIR=$NETWORK/sentry/sentry

      # From launch/node/heimdall/setup.sh does for testnet/sentry nodes
      HEIMDALL_DIR=./build
      heimdalld init --home $HEIMDALL_DIR
      cp -rf $LAUNCH_NODE_DIR/heimdall/config/genesis.json $HEIMDALL_DIR/config/genesis.json
      # 'Setup config files' section of full node binaries docs
      # Also make ports configurable
      substituteInPlace $HEIMDALL_DIR/config/config.toml \
        --replace 'seeds = ""' 'seeds="4cd60c1d76e44b05f7dfd8bab3f447b119e87042@54.147.31.250:26656,b18bbe1f3d8576f4b73d9b18976e71c65e839149@34.226.134.117:26656"' \
        --replace 'proxy_app = "tcp://127.0.0.1:26658"' 'proxy_app = "tcp://127.0.0.1:${toString proxy_app_port}"' \
        --replace 'prof_laddr = "localhost:6060"' 'prof_laddr = "localhost:${toString prof_laddr_port}"' \
        --replace 'laddr = "tcp://127.0.0.1:26657"' 'laddr = "tcp://127.0.0.1:${toString rpc_laddr_port}"' \
        --replace 'laddr = "tcp://0.0.0.0:26656"' 'laddr = "tcp://0.0.0.0:${toString p2p_laddr_port}"'
      substituteInPlace $HEIMDALL_DIR/config/heimdall-config.toml \
        --replace 'eth_rpc_url = "http://localhost:9545"' 'eth_rpc_url = "${eth_rpc_url}"' \
        --replace 'bor_rpc_url = "http://localhost:8545"' 'bor_rpc_url = "${bor_rpc_url}"' \
        --replace 'tendermint_rpc_url = "http://0.0.0.0:26657"' 'tendermint_rpc_url = "http://0.0.0.0:${toString rpc_laddr_port}"' \
        --replace 'heimdall_rest_server = "http://0.0.0.0:1317"' 'heimdall_rest_server = "http://0.0.0.0:${toString heimdall_rest_server_port}"'
    '';
    installPhase = ''
      mkdir $out
      cp -r build/* $out
      # These are not deterministic so must be generated at runtime
      rm $out/config/node_key.json
      rm $out/config/priv_validator_key.json
    '';
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
