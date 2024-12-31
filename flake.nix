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
    impermanence = {
      url = "github:nix-community/impermanence";
    };
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
    nix-std.url = "github:chessai/nix-std";
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    harpoon = {
      url = "github:ThePrimeagen/harpoon/harpoon2";
      flake = false;
    };
    immich-shield = {
      url = "https://img.shields.io/github/v/release/immich-app/immich.json";
      flake = false;
    };
    homer-shield = {
      url = "https://img.shields.io/github/v/release/bastienwirtz/homer.json";
      flake = false;
    };
    jellyfin-shield = {
      url = "https://img.shields.io/github/v/release/linuxserver/docker-jellyfin.json";
      flake = false;
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
    hyprland-qtutils = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:hyprwm/hyprland-qtutils";
    };
    nixpkgs-working-wezterm.url = "github:nixos/nixpkgs/2b2eca6ef54c765b0a830830196701af42d66642";
    wezterm-master.url = "github:wez/wezterm?dir=nix";
    nh = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:viperML/nh";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      eachSystem =
        f:
        nixpkgs.lib.genAttrs ([
          "aarch64-darwin"
          "x86_64-linux"
        ]) (system: f nixpkgs.legacyPackages.${system});

      treefmtEval = eachSystem (
        pkgs:
        inputs.treefmt-nix.lib.evalModule pkgs (
          { pkgs, ... }:
          {
            projectRootFile = "flake.nix";
            # https://github.com/numtide/treefmt-nix?tab=readme-ov-file#supported-programs
            programs = {
              prettier.enable = true;
              nixfmt.enable = true;
            };
          }
        )
      );
    in
    {

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);
      # for `nix flake check`
      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });

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
          inputs.nixvim.nixDarwinModules.nixvim
          inputs.stylix.darwinModules.stylix
          {
            nixpkgs.overlays = [
              inputs.nur.overlay
              inputs.nixpkgs-firefox-darwin.overlay
            ];
          }
          {
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./machines/work
        ];
      };

      nixosConfigurations.aesop = nixpkgs.lib.nixosSystem {
        specialArgs =
          let
            vars = import ./machines/aesop/vars.nix;
          in
          {
            inherit inputs vars;
            lib = nixpkgs.lib.extend (
              final: prev:
              (import ./lib/nixos {
                lib = final;
                inherit vars;
              })
            );
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
          inputs.nixvim.nixosModules.nixvim
          inputs.stylix.nixosModules.stylix
          { nixpkgs.overlays = [ inputs.nur.overlay ]; }
          {
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./secrets
          ./machines/aesop
        ];
      };

      nixosConfigurations.skylake = nixpkgs.lib.nixosSystem {
        specialArgs =
          let
            vars = import ./machines/skylake/vars.nix;
          in
          {
            inherit inputs vars;
            lib = nixpkgs.lib.extend (
              final: prev:
              (import ./lib/nixos {
                lib = final;
                inherit vars;
              })
            );
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
          inputs.nixvim.nixosModules.nixvim
          inputs.stylix.nixosModules.stylix
          { nixpkgs.overlays = [ inputs.nur.overlay ]; }
          {
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./secrets
          ./machines/skylake
        ];
      };

      deploy.nodes = {
        skylake = {
          hostname = "skylake";
          profiles.system = {
            path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.skylake;
            sshUser = "misi";
            user = "root";
            sshOpts = [
              "-t"
              "-p"
              "69"
              "-i"
              "~/.ssh/skylake"
            ];
            magicRollback = false;
            autoRollback = false;
            remoteBuild = true;
            interactiveSudo = true;
            skipChecks = true;
          };
        };
      };
    };
}
