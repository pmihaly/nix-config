{
  username = "mihaly.papp";
  rebuildSwitch = "while true; do darwin-rebuild switch --flake ~/.nix-config#mac --option extra-experimental-features pipe-operators --impure && break; done";
}
