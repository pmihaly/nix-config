{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.vscode;
in
{
  imports = [
    # Source: https://gist.github.com/piousdeer/b29c272eaeba398b864da6abf6cb5daa
    # Make vscode settings writable

    (import (builtins.fetchurl {
      url = "https://gist.githubusercontent.com/piousdeer/b29c272eaeba398b864da6abf6cb5daa/raw/41e569ba110eb6ebbb463a6b1f5d9fe4f9e82375/mutability.nix";
      sha256 = "4b5ca670c1ac865927e98ac5bf5c131eca46cc20abf0bd0612db955bfc979de8";
    }) { inherit config lib; })

    (import (builtins.fetchurl {
      url = "https://gist.githubusercontent.com/piousdeer/b29c272eaeba398b864da6abf6cb5daa/raw/41e569ba110eb6ebbb463a6b1f5d9fe4f9e82375/vscode.nix";
      sha256 = "fed877fa1eefd94bc4806641cea87138df78a47af89c7818ac5e76ebacbd025f";
    }) { inherit config lib pkgs; })
  ];
  options.modules.vscode = {
    enable = mkEnableOption "vscode";
  };
  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc-icons
        eamodio.gitlens
        asvetliakov.vscode-neovim
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
      ];
      keybindings = [
        {
          key = "ctrl+t";
          command = "workbench.action.terminal.toggleTerminal";
        }
      ];
      userSettings = {
        "workbench.iconTheme" = "catppuccin-frappe";
        "editor.fontLigatures" = true;
        "editor.cursorSmoothCaretAnimation" = "on";
        "editor.smoothScrolling" = true;
        "editor.minimap.enabled" = false;
        "editor.formatOnSave" = true;
        "files.autoSave" = "onFocusChange";
        "files.insertFinalNewline" = true;
        "files.trimTrailingWhitespace" = true;
        "explorer.autoReveal" = true;
        "workbench.editor.enablePreview" = false;
        "workbench.editor.tabCloseButton" = "right";
        "workbench.editor.tabSizing" = "shrink";
        "workbench.panel.defaultLocation" = "right";
        "workbench.settings.editor" = "json";
        "workbench.sideBar.location" = "right";
        "[javascript]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "extensions.experimental.affinity" = {
          "asvetliakov.vscode-neovim" = 1;
        };
        "workbench.activityBar.location" = "hidden";
        "zenMode.showTabs" = "none";
        "terminal.integrated.defaultProfile.osx" = "tmux";
        "terminal.integrated.defaultProfile.linux" = "tmux";
        "extensions.ignoreRecommendations" = true;
      };
    };
  };
}
