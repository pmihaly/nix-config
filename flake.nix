{
  description = "My first nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = { url = "github:nix-community/impermanence"; };
    nur.url = "github:nix-community/NUR";
    img2theme = {
      url = "github:pmihaly/img2theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.darwin.follows = "darwin";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-firefox-darwin = {
      url = "github:bandithedoge/nixpkgs-firefox-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazygit = {
      type = "github";
      owner = "jesseduffield";
      repo = "lazygit";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt;
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

    darwinConfigurations.mac = inputs.darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs;
        vars = (import ./machines/work/vars.nix);
        platform = {
          isLinux = false;
          isDarwin = true;
        };
      };

      system = "aarch64-darwin";
      modules = [
        home-manager.darwinModules.home-manager
        {
          nixpkgs.overlays =
            [ inputs.nur.overlay inputs.nixpkgs-firefox-darwin.overlay ];
        }
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ./machines/work
      ];
    };

    nixosConfigurations.aesop = nixpkgs.lib.nixosSystem {
      specialArgs = let vars = import ./machines/aesop/vars.nix;
      in {
        inherit inputs vars;
        lib = nixpkgs.lib.extend (final: prev:
          (import ./lib/nixos {
            lib = final;
            inherit vars;
          }));
        platform = {
          isLinux = true;
          isDarwin = false;
        };
      };

      modules = [
        home-manager.nixosModules.home-manager
        inputs.agenix.nixosModules.default
        inputs.impermanence.nixosModules.impermanence
        inputs.nix-index-database.nixosModules.nix-index
        inputs.disko.nixosModules.disko
        { nixpkgs.overlays = [ inputs.nur.overlay ]; }
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ./secrets
        ./machines/aesop
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
        platform = {
          isLinux = true;
          isDarwin = false;
        };
      };

      modules = [
        home-manager.nixosModules.home-manager
        inputs.agenix.nixosModules.default
        inputs.impermanence.nixosModules.impermanence
        inputs.nix-index-database.nixosModules.nix-index
        inputs.disko.nixosModules.disko
        { nixpkgs.overlays = [ inputs.nur.overlay ]; }
        { home-manager.extraSpecialArgs = { inherit inputs; }; }
        ./secrets
        ./machines/skylake
      ];
    };

    deploy.nodes = {
      skylake = {
        hostname = "skylake.mihaly.codes";
        profiles.system = {
          path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos
            self.nixosConfigurations.skylake;
          sshUser = "misi";
          user = "root";
          sshOpts = [ "-p" "69" "-t" ];
          magicRollback = false;
          remoteBuild = true;
        };
      };
    };

  };
}
