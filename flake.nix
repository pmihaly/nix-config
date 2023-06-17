{
  description = "My first nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, darwin }: {

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
        ./pc-hardware.nix
        ./nixos.nix
      ];
    };
  };
}
