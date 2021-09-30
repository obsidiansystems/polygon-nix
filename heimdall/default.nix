{ lib, stdenv, buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "polygon-heimdall";
  version = (builtins.fromJSON (builtins.readFile ./thunk/github.json)).tag;

  src = import ./thunk/thunk.nix;

  runVend = true;
  vendorSha256 = "0cl44n2jd45qgpc0s55zx8xab89gvjhahq7c41mbs7rzdy5x0p89";

  doCheck = false;

  outputs = [ "out" ];

  subPackages = [
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
    "cmd/heimdallcli"
    "cmd/heimdalld"
  ];

}
