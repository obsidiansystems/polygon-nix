# polygon-nix
Deploy a Polygon Node with Nix instead of Ansible

## Using matic-cli

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
