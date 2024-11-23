{
  timeZone = "Europe/Budapest";
  persistDir = "/persist";
  username = "misi";
  rebuildSwitch = "sudo nixos-rebuild switch --flake ~/.nix-config#aesop --option extra-experimental-features pipe-operators";
  storage = "/home/misi/storage";
}
