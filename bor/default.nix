{ lib, stdenv, buildGoModule, fetchFromGitHub, libobjc, IOKit }:

# N.B. Adapted from Nixpkgs' go-ethereum package.

let
  # A list of binaries to put into separate outputs
  bins = [
    "bor"
  ];

in buildGoModule rec {
  pname = "polygon-bor";
  version = (builtins.fromJSON (builtins.readFile ./thunk/github.json)).tag;

  src = import ./thunk/thunk.nix;

  runVend = true;
  vendorSha256 = "1rfg2368fgjxdqz1y0wa5iplrjwpng523and3fghs5j2430103hf";

  doCheck = false;

  outputs = [ "out" ] ++ bins;

  # Move binaries to separate outputs and symlink them back to $out
  postInstall = ''
    cp $out/bin/geth $out/bin/bor
  '' + lib.concatStringsSep "\n" (
    builtins.map (bin: "mkdir -p \$${bin}/bin && mv $out/bin/${bin} \$${bin}/bin/ && ln -s \$${bin}/bin/${bin} $out/bin/") bins
  );

  subPackages = [
    "cmd/abidump"
    "cmd/abigen"
    "cmd/bootnode"
    "cmd/checkpoint-admin"
    "cmd/clef"
    "cmd/devp2p"
    "cmd/ethkey"
    "cmd/evm"
    "cmd/faucet"
    "cmd/geth"
    "cmd/p2psim"
    "cmd/puppeth"
    "cmd/rlpdump"
    "cmd/utils"
  ];

  # Fix for usb-related segmentation faults on darwin
  propagatedBuildInputs =
    lib.optionals stdenv.isDarwin [ libobjc IOKit ];
}
