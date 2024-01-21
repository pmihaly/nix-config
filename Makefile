switch-mac:
	darwin-rebuild switch --flake .#mac

update:
	./update.nu

update-finances:
	nix flake lock --update-input finances
