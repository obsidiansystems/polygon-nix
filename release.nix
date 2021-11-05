let
  self = import ./. {};
in {
  service = import ./service.nix { config = {}; };
  launch = self.launch-src;
  heimdall-testnet = self.heimdall-testnet;
  heimdall = self.heimdall.gopkg;
  bor = self.bor;
}
