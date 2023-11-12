{ pkgs, customflakes, ... }:
{
  home.stateVersion = "22.05";

  nixpkgs.overlays = import ./overlays;

  imports = [ ./modules ];

  modules = {
    vscode.enable = true;
    firefox.enable = true;
    nvim.enable = true;
    lazygit.enable = true;
    shell.enable = true;
    mpv.enable = true;
    lf.enable = true;
    kitty.enable = true;
    newsboat.enable = true;
  };

  home.packages =
    let
      work = with pkgs; [
        awscli
        git-lfs
        saml2aws
        openssl
        obsidian
        jwt-cli
        libossp_uuid # uuid from cli
      ];
    in
    work ++ (with pkgs; [
      keepassxc
      slack
      lazydocker
      syncthing
      act # running github actions locally
      massren # mass file rename
      discord
      nix-tree # visualisation of nix derivations
      tig # prettier git tree
      keepass-diff # diffing .kdbx files
      iosevka-custom
      nerdfonts-fira-code
      zathura # pdf reader
      transmission
      anki-bin
    ])
    ++ (with customflakes; [
      img2theme.packages."${pkgs.system}".default
    ]);

  programs.tmux = {
    enable = true;
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.nord
      tmuxPlugins.fuzzback
      tmuxPlugins.fzf-tmux-url
    ];
    mouse=true;
    clock24=true;
    extraConfig = ''
      set-option -g status-interval 5
      set-option -g automatic-rename on
      set-option -g automatic-rename-format '#{b:pane_current_path} #{pane_current_command}'
      set-option -g status off
      set-option -g default-command zsh

      set-option -g prefix C-Space
      bind-key C-Space send-prefix

      bind j display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command}' | grep -v \"$(tmux display-message -p '#I') \" | fzf | choose 0 | xargs tmux select-window -t"

      bind k display-popup -E "tmux list-windows -F '#{window_index} #{b:pane_current_path} #{pane_current_command}' | fzf --multi | choose 0 | xargs -I{} tmux kill-window -t {}"

      set -g @fuzzback-bind ?
      set -g @fzf-url-bind u
    '';
  };

}
