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

After a `nixos-rebuild switch`, the nodes will run as systemd services. You can monitor each of the components with:

```shell
journalctl --unit polygon-mumbai-geth.service --follow
journalctl --unit polygon-mumbai-heimdalld.service --follow
journalctl --unit polygon-mumbai-heimdalld-rest-server.service --follow
journalctl --unit polygon-mumbai-bor.service --follow
```

Note that Heimdall can take as long as a week to fully sync, so you will probably want to use the snapshots available
from https://snapshots.matic.today/ in order to reduce sync time to a few hours. There are instructions
[here](https://forum.matic.network/t/snapshot-instructions-for-heimdall-and-bor/2278) which will
work, but you need to put the data in a different place: the services store data under `/var/lib/polygon/mumbai`.

## Bumping after a hard fork

Polygon seems to hard fork fairly often, and when it does, the update instructions (by Polygon themselves) are posted
[here](https://forum.polygon.technology/c/polygon-mumbai/19).

Typically, you'll need to bump `bor` to the new tag:

```shell
nix-thunk unpack bor/thunk
cd bor/thunk
git checkout v0.2.13-beta2
cd ../..
nix-thunk pack bor/thunk
```

If the tag does not exist on a remote branch, `nix-thunk` will require you to push a branch to a fork (you can't point
directly at a tag).

Then upon rebuilding, it's common that `vendorSha256` in `bor/default.nix` will need bumping too. Just run the build and
nix should tell you the new sha256.

In order to pick up the new genesis block the launch directory will need bumping. It's specified in `default.nix` as
`launchSrc`. Point it to the new revision and update the sha256 (you can get this sha256 via nix-build too, but you may
need to flip the first bit (0 -> 1 or 1 -> 0) before running the build).

After this, just redeploying the nodes (simply rebuild the system after pointing to the new polygon-nix commit) should
work. In some cases you'll also need to manually rewind the chain by connecting over IPC after updating everything:

```shell
sudo $(nix-build -A bor)/bin/bor attach /var/lib/polygon/mumbai/bor/data/bor.ipc

Welcome to the Geth JavaScript console!
<snip>
> debug.setHead("0x1521538")
```

Naturally the block height you need to set there will be different, but it should be specified in the node update
instructions on the Polygon forum.

## Using matic-cli [not recommended]

You need to have Docker installed and running on your system.
For NixOS systems, add something like this to your system config:

```nix
{
  virtualisation.docker.enable = true;
  # Only add this if you run into cgroup issues when launching containers (happens with v19)
  systemd.enableUnifiedCgroupHierarchy = false;
}
```

With the docker daemon running, you should now be able to setup and run a local devnet.

### Setup

Setup the network in a fresh directory as such:
```shell
$ mkdir devnet
$ cd devnet
$ echo '{"heimdallImage": "heimdall:fix-logs"}' > config.json
$ nix-shell /path/to/polygon-nix -A matic-cli-shell
[nix-shell:devnet]$ docker load < $(nix-build /path/to/polygon-nix -A heimdall.docker)
[nix-shell:devnet]$ matic-cli setup devnet
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
