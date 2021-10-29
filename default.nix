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
  bor = self.callPackage ./bor {
    inherit (pkgs.darwin) libobjc;
    inherit (pkgs.darwin.apple_sdk.frameworks) IOKit;
  };
  heimdall = self.callPackage ./heimdall {
    network = network;
  };
  # Setup the heimdalld directory with $(nix-build -A setup-heimdalld) path-to-heimdall-dir
  setup-heimdalld = pkgs.writeScript "setup-heimdalld" ''
    #!${pkgs.runtimeShell}
    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      mkdir -p "$DIR"
    fi

    ${heimdall}/bin/heimdalld init --home $DIR

    cp -fr ${heimdall-testnet}/* "$DIR"
  '';
  # Setup the bor directory with $(nix-build -A setup-bor) path-to-bor-dir
  setup-bor = pkgs.writeScript "setup-bor" ''
    #!${pkgs.runtimeShell}
    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      mkdir -p "$DIR"
    fi

    NETWORK=${launchSrc}/testnet-v4
    LAUNCH_NODE_DIR=$NETWORK/sentry/sentry

    # From launch/node/bor/setup.sh does for testnet/sentry nodes
    mkdir -p $DIR/keystore
    ${bor}/bin/bor --datadir $DIR/data init $LAUNCH_NODE_DIR/bor/genesis.json
    cp $LAUNCH_NODE_DIR/bor/static-nodes.json $DIR/data/bor/static-nodes.json
    bootnode -genkey $DIR/data/nodekey
  '';
  # Start heimdalld (after running setup-heimdall) with $(nix-build -A run-heimdalld) path-to-heimdall-dir
  run-heimdalld = pkgs.writeScript "run-heimdalld" ''
    #!${pkgs.runtimeShell}

    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      echo "Missing heimdall data directory $DIR, use setup-heimdall first"
      exit 1
    fi

    cd "$DIR"
    ${heimdall}/bin/heimdalld start --home .
  '';
  # Start the heimdalld rest server (after heimdall has synced) with $(nix-build -A run-heimdalld-rest-server) path-to-heimdall-dir
  run-heimdalld-rest-server = pkgs.writeScript "run-heimdalld-rest-server" ''
    #!${pkgs.runtimeShell}

    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      echo "Missing heimdall data directory $DIR, use setup-heimdall first"
      exit 1
    fi

    cd "$DIR"
    ${heimdall}/bin/heimdalld rest-server --home .
  '';
  # Start bor (after heimdall has synced) with $(nix-build -A run-bor) path-to-bor-dir
  run-bor = pkgs.writeScript "run-bor" ''
    #!${pkgs.runtimeShell}

    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      echo "Missing bor data directory $DIR, use setup-bor first"
      exit 1
    fi

    cd "$DIR"
    ${bor}/bin/bor --datadir $DIR/data \
      --port 30303 \
      --http --http.addr '0.0.0.0' \
      --http.vhosts '*' \
      --http.corsdomain '*' \
      --http.port 8545 \
      --ipcpath $DIR/data/bor.ipc \
      --http.api 'eth,net,web3,txpool,bor' \
      --syncmode 'full' \
      --networkid '80001' \
      --miner.gaslimit '20000000' \
      --miner.gastarget '20000000' \
      --txpool.nolocals \
      --txpool.accountslots 16 \
      --txpool.globalslots 131072 \
      --txpool.accountqueue 64 \
      --txpool.globalqueue 131072 \
      --txpool.lifetime '1h30m0s' \
      --maxpeers 200 \
      --metrics \
      --pprof --pprof.port 7071 --pprof.addr '0.0.0.0' \
      --bootnodes "enode://320553cda00dfc003f499a3ce9598029f364fbb3ed1222fdc20a94d97dcc4d8ba0cd0bfa996579dcc6d17a534741fb0a5da303a90579431259150de66b597251@54.147.31.250:30303"
  '';
  # Start the heimdalld bridge (after bor has synced) with $(nix-build -A run-heimdalld-bridge) path-to-heimdall-dir
  run-heimdalld-bridge = pkgs.writeScript "run-heimdalld-bridge" ''
    #!${pkgs.runtimeShell}

    set -eux

    DIR=$(realpath $1)

    if [ ! -d "$DIR" ]; then
      echo "Missing heimdall data directory $DIR, use setup-heimdall first"
      exit 1
    fi

    cd "$DIR"
    ${heimdall}/bin/bridge start --all --home .
  '';
  # Patched heimdall testnet files
  heimdall-testnet = pkgs.stdenv.mkDerivation {
    name = "heimdall-testnet";
    src = launchSrc;
    buildInputs = [ heimdall ];
    buildPhase = ''
      NETWORK=./testnet-v4
      LAUNCH_NODE_DIR=$NETWORK/sentry/sentry

      # From launch/node/heimdall/setup.sh does for testnet/sentry nodes
      HEIMDALL_DIR=./build
      heimdalld init --home $HEIMDALL_DIR
      cp -rf $LAUNCH_NODE_DIR/heimdall/config/genesis.json $HEIMDALL_DIR/config/genesis.json
      # 'Setup config files' section of full node binaries docs
      substituteInPlace $HEIMDALL_DIR/config/config.toml \
        --replace 'seeds = ""' 'seeds="4cd60c1d76e44b05f7dfd8bab3f447b119e87042@54.147.31.250:26656,b18bbe1f3d8576f4b73d9b18976e71c65e839149@34.226.134.117:26656"'
      # substituteInPlace $HEIMDALL_DIR/config/heimdall-config.toml \
      #   --replace 'eth_rpc_url = "http://localhost:9545"' 'eth_rpc_url="https://goerli.infura.io/v3/7e72bb77c5f14d2e9a11b0ce53f4cfc2"'
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
