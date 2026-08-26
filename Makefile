update:
	./update.nu

update-finances:
	nix flake lock --update-input finances

skylake:
	./scripts/deploy-skylake.sh
