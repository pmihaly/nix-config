switch-mac:
	darwin-rebuild switch --flake .#mac

switch-pc:
	nixos-rebuild switch --flake .#pc

update:
	nix flake update

fmt:
	find **/*.nix | xargs nix fmt
