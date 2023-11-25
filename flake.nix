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
    agenix.url = "github:ryantm/agenix";
    firefox-darwin-dmg = {
      url =
        "https://download.mozilla.org/?product=firefox-latest&os=osx&lang=en-US";
      flake = false;
    };
    lf-icons = {
      url =
        "https://raw.githubusercontent.com/gokcehan/lf/master/etc/icons.example";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, hyprland, nur, agenix, ...
    }@inputs: {
      formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

      darwinConfigurations.mac = darwin.lib.darwinSystem {
        specialArgs = { inherit inputs; };

        system = "aarch64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          { nixpkgs.overlays = [ nur.overlay ]; }
          { home-manager.extraSpecialArgs = { inherit inputs; }; }
          ./darwin.nix
        ];
      };

      nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };

        modules = [
          home-manager.nixosModules.home-manager
          hyprland.nixosModules.default
          { nixpkgs.overlays = [ nur.overlay ]; }
          { home-manager.extraSpecialArgs = { inherit inputs; }; }
          ./pc-hardware.nix
          ./nixos.nix
        ];
      };

      nixosConfigurations.skylake = nixpkgs.lib.nixosSystem {
        specialArgs = let vars = import ./machines/skylake/vars.nix;
        in {
          inherit inputs vars;
          lib = nixpkgs.lib.extend (final: prev:
            (import ./lib/nixos {
              lib = final;
              inherit vars;
            }));
        };

        modules = [
          home-manager.nixosModules.home-manager
          agenix.nixosModules.default
          { home-manager.extraSpecialArgs = { inherit inputs; }; }
          ./secrets
          ./machines/skylake
        ];
      };
    };
}
