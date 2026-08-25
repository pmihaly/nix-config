{
  username = "mpapp";
  rebuildSwitch = "NIXPKGS_ALLOW_BROKEN=1 nh darwin switch ~/.nix-config --hostname work -- --impure --option extra-experimental-features pipe-operators";
}
