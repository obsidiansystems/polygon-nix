{ stdenv }: stdenv.mkDerivation {
  name = "matic-cli-src";
  src = import ./thunk/thunk.nix;
  patches = [ ./heimdall-image.patch ];
  installPhase = "cp -r . $out";
}
