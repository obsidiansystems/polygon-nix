# polygon-nix
Deploy a Polygon Node with Nix instead of Ansible

## NixOS Service

Clone this repo under `/etc/nixos/polygon-nix`, and add the following to your NixOS configuration:

```nix
{
  imports = [ ./hardware-configuration.nix ./polygon-nix/service.nix ];

  services.polygon = {
    enable = true;
    # The ports below are all the default values, but you can change them if necessary.
    geth.ports = {
      http = 9545;
      listen = 30300;
    };
    bor.ports = {
      http = 8545;
      listen = 30303;
      prof = 7071;
    };
    heimdall.ports = {
      p2p = 26656;
      rpc = 26657;
      listen = 26658;
      prof = 6060;
      restServer = 1317;
    };
  };
}
```

## Using matic-cli

You'll need to install docker version 19 on your system (the heimdall image does not work in later versions, see
https://github.com/maticnetwork/heimdall/issues/729).

For NixOS systems, add something like this to your system config:

```nix
let
  nixos1909 = import (builtins.fetchTarball {
    name = "nixos-19.09";
    url = "https://github.com/nixos/nixpkgs/archive/75f4ba05c63be3f147bcc2f7bd4ba1f029cedcb1.tar.gz";
    sha256 = "157c64220lf825ll4c0cxsdwg7cxqdx4z559fdp7kpz0g6p8fhhr";
  }) {};
in {
  systemd.enableUnifiedCgroupHierarchy = false;
  virtualisation.docker = {
    enable = true;
    package = nixos1909.docker;
  };
}
```

With the docker daemon running, you should now be able to setup and run a local devnet.

### Setup

Setup the network in a fresh directory as such:
```shell
$ mkdir devnet
$ cd devnet
$ nix-shell /path/to/polygon-nix -A matic-cli-shell
[nix-shell:/path/to/devnet]$ matic-cli setup devnet
```

### Running the network

Start ganache:
```shell
[nix-shell:/path/to/devnet]$ bash docker-ganache-start.sh
```

And in another shell start the other containers:
```shell
[nix-shell:/path/to/devnet]$ bash docker-heimdall-start-all.sh
[nix-shell:/path/to/devnet]$ bash docker-bor-setup.sh
[nix-shell:/path/to/devnet]$ bash docker-bor-start-all.sh
```

To stop and remove all images, use `docker-compose down`.
