switch-mac:
	darwin-rebuild switch --flake .#mac

switch-pc:
	nixos-rebuild switch --flake .#pc

update:
	./update.nu

update-finances:
	nix flake lock --update-input finances

fmt:
	find **/*.nix | xargs nix fmt
