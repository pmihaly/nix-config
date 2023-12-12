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
    simple-nixos-mailserver.url =
      "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-23.05";
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

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

    darwinConfigurations.mac = inputs.darwin.lib.darwinSystem {
      specialArgs = { inherit inputs; };

      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        { nixpkgs.overlays = [ inputs.nur.overlay ]; }
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ./darwin.nix
      ];
    };

    nixosConfigurations.pc = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };

      modules = [
        home-manager.nixosModules.home-manager
        inputs.hyprland.nixosModules.default
        { nixpkgs.overlays = [ inputs.nur.overlay ]; }
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
        inputs.agenix.nixosModules.default
        inputs.simple-nixos-mailserver.nixosModule
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ./secrets
        ./machines/skylake
      ];
    };

    nixosConfigurations.post-office = nixpkgs.lib.nixosSystem {
      specialArgs = let vars = import ./machines/post-office/vars.nix;
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
        inputs.agenix.nixosModules.default
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        inputs.simple-nixos-mailserver.nixosModule
        ./secrets
        ./machines/post-office
      ];
    };
  };
}
