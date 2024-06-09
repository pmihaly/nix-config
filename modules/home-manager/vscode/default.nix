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
  options.modules.vscode = {
    enable = mkEnableOption "vscode";
  };
  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        catppuccin.catppuccin-vsc
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
      };
    };
  };
}
