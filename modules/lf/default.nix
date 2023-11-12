{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.lf;

in {
  options.modules.lf = { enable = mkEnableOption "lf"; };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      massren
      du-dust
    ];
    programs.lf = {
      enable = true;
      settings = {
        scrolloff = 999;
        hidden = true;
        smartcase = true;
      };
      commands = {
        delete =
          ''
          ''${{
            clear; tput cup $(($(tput lines)/3)); tput bold
              set -f
              printf "%s\n\t" "$fx"
              printf "delete? [y/N] "
              read ans
              [ "$ans" = "y" ] && echo "$fx" | tr ' ' '\ ' | xargs -I{} rm -rf -- "{}"
          }}
        '';
        mkdirWithParent = '' $mkdir -p "$(echo $* | tr ' ' '\ ')" '';
        touchWithParent = '' $mkdir -p "$(dirname "$*")" && touch "$*" '';
        open = '' $$EDITOR $f '';
      };
      keybindings = {
        D = "delete";
        U = "!dust";
        R = "!massren";
        m = "push :mkdirWithParent<space>";
        t = "push :touchWithParent<space>";
        "<enter>" = "open";
        A = "rename"; # at the very end
          c = "push A<c-u>"; # new rename
          I = "push A<c-a>"; # at the very beginning
          i = "push A<a-b><a-b><a-f>"; # before extention
          a = "push A<a-b>"; # after extention
          M = "mark-save";
      };
    };

  };
}
