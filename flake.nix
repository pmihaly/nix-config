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
    arion.url = "github:hercules-ci/arion";
  };

  outputs = { self, nixpkgs, home-manager, darwin, hyprland, nur, img2theme, arion }: {
    darwinConfigurations.mac = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        { nixpkgs.overlays = [ nur.overlay ]; }
        (import ./darwin.nix { customflakes = { inherit img2theme; }; })
      ];
    };

    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        hyprland.nixosModules.default
        { nixpkgs.overlays = [ nur.overlay ]; }
        ./pc-hardware.nix
        (import ./nixos.nix { customflakes = { inherit img2theme; }; })
      ];
    };

    nixosConfigurations.skylake = nixpkgs.lib.nixosSystem {
      modules = [
        home-manager.nixosModules.home-manager
        arion.nixosModules.arion
        ./machines/skylake/hardware.nix
        ./machines/skylake
      ];
    };
  };
}
