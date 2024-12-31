{
  username = "mihaly.papp";
  rebuildSwitch = "while true; do nh darwin switch ~/.nix-config --hostname mac -- --impure --option extra-experimental-features pipe-operators --impure && break; done";
}
