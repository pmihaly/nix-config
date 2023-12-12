{ pkgs, lib, vars, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ../../modules/nixos
  ];

  boot.cleanTmpDir = true;
  zramSwap.enable = true;
  networking.hostName = "post-office";
  networking.domain = "";

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

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDGabFdyVQOK8ecT2f8wGN+E/2axFQ+0XlJW2V5gph5vbouTxqol7VLmu5+Sz+ZQzZgeEKrtVK0gAYaNi8NSpTN4b6jS1ElfTo7U3fvoI9NMeqIZjvzlIpekL3sMO4CVpKkFowDv/TH3fBTxqwZQ7PZYBxtuvDdhVUwoK/uuFeOe175PRQVZeXYdn+jchkOfldglp73WbyPIwA05jYNlCi7TaFCjWX4FlvmyC4rEm9Fy4LKo6A3WFR3V9LiFgbN8AvAhyPkfeE/hRQSN7Og4geUOR2DT3tZLWm0Sry8leSWGBGAiasHzD23CHbDnc+x1b3FR3xj0Wejct13x5OqVPpqVm+LudnOZDzty9lvFOR1bDcbi7WzXXg7Es31DtAKguf1SLhEgqP73I6IfKdYJZEXxe1IFshSivjK2FVc0Po4pHZB/SNpQWRC1K5cJR2kBqz7+pY4dkwHseFE4tS/BtvLCZkx6DrKtYv5qbk4CtzcG/WSH1ZoNpL2gqe16xU1w/fti0e/IrnY4DLBPJsP0z5bx9vtEwDAGC/N4S9YSjSh8aTzPsBoZZsB8GR528vrh+p1zuhaPIT+aa3jDJ1nx7j1h06BYLHONsw4PyS6tm6tlszzTIiPggHb7Cm6KegkvvkowAK6t8RRsu5mFj4xC/CM/b2wIyAT6l4pP+le9fV+2w=="
  ];

  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.username;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
    ];
  };

  programs.zsh.enable = true;

  home-manager.users.${vars.username} = {
    home.stateVersion = "22.05";
    imports = [ ../../modules ];

    modules = {
      nvim.enable = true;
      git.enable = true;
      shell.enable = true;
      lf.enable = true;
    };
  };

  nixpkgs.config.allowUnfree = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  nix = {
    settings.experimental-features = "nix-command flakes";
    settings.auto-optimise-store = true;
  };
}
