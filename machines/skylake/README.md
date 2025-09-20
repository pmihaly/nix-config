# setup

1. set devices in `disko.nix` to disks in `ls /dev/disk/by-id/`
1. `sudo sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- --mode destroy,format,mount --flake github:pmihaly/nix-config#skylake`
1. `sudo nixos-install --max-jobs 3 --option extra-experimental-features pipe-operators --flake github:pmihaly/nix-config#skylake`
1. copy ssh private key (which is in agenix recipients) into `/mnt/persist/etc/ssh/ssh_host_ed25519_key`

## restore backup

`sudo /run/current-system/sw/bin/restic-skylake-backup --repo s3:https://s3.amazonaws.com/misibackups/skylake restore latest --target /`
