{
  description = "My first nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    hyprland.url = "github:hyprwm/Hyprland";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, home-manager, darwin, hyprland, nur }: {

    darwinConfigurations."mac" = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        ./darwin.nix
      ];
    };

    nixosConfigurations."pc" = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        hyprland.nixosModules.default
        nur.nixosModules.nur
        ./pc-hardware.nix
        ./nixos.nix
      ];
    };
  };
}
