{
  platform,
  inputs,
  pkgs,
  vars,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.nix;
in
{
  options.modules.nix = {
    enable = mkEnableOption "nix";
  };
  config = mkIf cfg.enable (mkMerge [
    {
      nixpkgs.overlays = import ../../overlays;

      nixpkgs.config.allowUnfree = true;

      nix = {
        nixPath = [ "nixpkgs=/etc/channels/nixpkgs" ];
        settings = {
          experimental-features = [
            "nix-command"
            "flakes"
            "pipe-operators"
          ];
          trusted-users = [ vars.username ];

          # Persistent ccache for the ardour overlay (overlays/default.nix):
          # bind-mount a writable cache dir into every sandbox (non-store
          # directories in extra-sandbox-paths are mounted read-write). The
          # tmpfiles rule below creates it at boot — aesop's root is tmpfs
          # (impermanence), so the cache is deliberately per-boot (a cache,
          # not state); within a boot session it survives repeated builds.
          # 0770 root:nixbld lets sandboxed builds (uid nixbld) write while
          # regular users cannot.
          extra-sandbox-paths = [ "/var/cache/ccache" ];
        };
      };

      # ccache target dir must exist before any build runs (nix-daemon
      # bind-mounts it per-build; tmpfiles runs in sysinit, before the daemon).
      systemd.tmpfiles.rules = [ "d /var/cache/ccache 0770 root nixbld -" ];

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      environment.etc."channels/nixpkgs".source = inputs.nixpkgs.outPath;

      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;

      home-manager.users.${vars.username} = {
        imports = [
          inputs.agenix.homeManagerModules.default
          inputs.nixvim.homeModules.default
          inputs.nix-index-database.homeModules.nix-index
          ../../secrets/home-manager
        ];

        home.packages = with pkgs; [
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
          deploy-rs
          nix-tree # visualisation of nix derivations
        ];

        programs.nix-index-database.comma.enable = true;

        modules.persistence.directories = [ ".nix-config" ];
      };
    }

    (optionalAttrs platform.isLinux { nix.gc.dates = "weekly"; })

    (optionalAttrs platform.isDarwin {
      homebrew = {
        enable = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          cleanup = "zap";
        };
      };
    })
  ]);
}
