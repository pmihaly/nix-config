switch-mac:
	darwin-rebuild switch --flake .#mac

update:
	nix flake update
