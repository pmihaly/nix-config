{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.vscode;

in {
  options.modules.vscode = { enable = mkEnableOption "vscode"; };
  config = mkIf cfg.enable {
    programs.vscode = {
      enable = true;
      enableExtensionUpdateCheck = false;
      enableUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        arcticicestudio.nord-visual-studio-code
        eamodio.gitlens
        asvetliakov.vscode-neovim
        esbenp.prettier-vscode
        dbaeumer.vscode-eslint
      ];
      userSettings = {
        "workbench.colorTheme" = "Nord";
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
      };
    };
  };
}
