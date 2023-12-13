{ pkgs, lib, vars, ... }: {
  imports = [ ../../modules/nixos ./hardware.nix ];
  nixpkgs.overlays = import ../../overlays;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";
    imports = [ ../../modules/home-manager ];

    modules = {
      nvim.enable = true;
      git.enable = true;
      shell.enable = true;
      lf.enable = true;
      newsboat.enable = true;
    };
  };

  modules = {
    nginx.enable = true;
    jellyfin.enable = false;
    homer.enable = true;
    authelia.enable = true;
    deluge.enable = false;
    arr.enable = false;
    endlessh.enable = true;
    monitoring.enable = false;
    hledger.enable = false;
    duckdns.enable = true;
    paperless.enable = false;
    syncthing.enable = true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  networking = {
    hostName = "skylake";
    dhcpcd.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    ports = [ 69 ];
    settings.PasswordAuthentication = false;
    hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  time.timeZone = vars.timeZone;
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

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
    ];
  };

  users.groups.multimedia.members = [ "${vars.username}" ];
  users.groups.backup.members = [ "paperless" "syncthing" "${vars.username}" ];

  programs.zsh.enable = true;

  nixpkgs.config.allowUnfree = true;

  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };

  system.stateVersion = "23.05";
}
