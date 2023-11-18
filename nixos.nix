{ config, pkgs, lib, inputs, ... }:

let utils = import ./utils.nix { inherit lib; };
in
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "nixos";
    dhcpcd.enable = true;
  };

  time.timeZone = "Europe/Budapest";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "hu_HU.UTF-8";
    LC_IDENTIFICATION = "hu_HU.UTF-8";
    LC_MEASUREMENT = "hu_HU.UTF-8";
    LC_MONETARY = "hu_HU.UTF-8";
    LC_NAME = "hu_HU.UTF-8";
    LC_NUMERIC = "hu_HU.UTF-8";
    LC_PAPER = "hu_HU.UTF-8";
    LC_TELEPHONE = "hu_HU.UTF-8";
    LC_TIME = "hu_HU.UTF-8";
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "misi";
      };
    };
  };

  programs.hyprland = {
    enable = true;
    xwayland = {
      enable = true;
    };
    nvidiaPatches = false;
  };

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.misi = {
    isNormalUser = true;
    description = "misi";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  fonts.packages = [
    pkgs.iosevka-custom
  ];

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = import ./overlays;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryFlavor = "gtk2";
  };

  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users."misi" =
    utils.recursiveMerge [
      ./homemanager.nix
      {
        home.packages = with pkgs; [
          swaybg # setting wallpapers in wayland
          wofi # wayland equivalent of rofi
          ytfzf
          wl-clipboard # `wl-copy` and `wl-paste`
        ];

        xdg.configFile = {
          hypr = {
            source = ./hypr;
            recursive = true;
          };
        };


        gtk = {
          enable = true;
          theme = {
            package = pkgs.nordic;
            name = "Nordic";
          };
          iconTheme = {
            package = pkgs.nordzy-icon-theme;
            name = "Nordzy";
          };
        };
      }
    ];

  system.stateVersion = "23.05";
}
