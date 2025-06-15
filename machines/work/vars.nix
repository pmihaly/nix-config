{
  username = "mihaly.papp";
  rebuildSwitch = "$env.NIXPKGS_ALLOW_BROKEN = 1; nh darwin switch ~/.nix-config --hostname work -- --impure";
}
