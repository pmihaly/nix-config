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
    img2theme.url = "github:pmihaly/img2theme";
  };

  outputs = { self, nixpkgs, home-manager, darwin, hyprland, nur, img2theme }: {

    darwinConfigurations."mac" = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        nur.hmModules.nur
        (import ./darwin.nix { customflakes = { inherit img2theme; }; })
      ];
    };

    nixosConfigurations."pc" = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        hyprland.nixosModules.default
        nur.hmModules.nur
        ./pc-hardware.nix
        (import ./nixos.nix { customflakes = { inherit img2theme; }; })
      ];
    };
  };
}
