{ pkgs, lib, stdenv, buildGoModule, fetchFromGitHub, network }:
let validNetworks = [ "mainnet" "mumbai" "local" ];
in
  assert (lib.assertOneOf "network" network validNetworks);
  rec {
    gopkg = buildGoModule rec {
      pname = "polygon-heimdall-" + network;
      version = (builtins.fromJSON (builtins.readFile ./thunk/github.json)).tag;

      src = import ./thunk/thunk.nix;
      # Patch the docker image to make /logs path absolute.
      # This allows running with docker v20.
      patches = [ ./docker.patch ];

      runVend = true;
      vendorSha256 = "0cl44n2jd45qgpc0s55zx8xab89gvjhahq7c41mbs7rzdy5x0p89";

      doCheck = false;

      outputs = [ "out" ];

      preBuild = ''
        go run helper/heimdall-params.template.go ${network}
      '';

      subPackages = [
        "bor"
        "cmd/heimdallcli"
        "cmd/heimdalld"
        "common"
        "contracts/erc20"
        "contracts/rootchain"
        "contracts/slashmanager"
        "contracts/stakemanager"
        "contracts/stakinginfo"
        "contracts/statereceiver"
        "contracts/statesender"
        "contracts/validatorset"
        "file"
        "gov"
        "helper"
      ];
    };

    docker = pkgs.dockerTools.buildImage {
      name = "heimdall";
      tag = "fix-logs";
      contents = [ gopkg pkgs.bash ];
      runAsRoot = ''
        #!${pkgs.runtimeShell}
        mkdir -p /root/heimdall
        mkdir -p /root/.heimdalld
        mkdir -p /logs
      '';
      config = {
        Volumes = {
          "/root/.heimdalld" = {};
          "/logs" = {};
        };
        WorkingDir = "/root/heimdall";
        Cmd = [ "/bin/heimdalld" ];
        Expose = [ 1317 26656 26657 ];
      };
    };
  }
