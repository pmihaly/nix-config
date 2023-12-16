{ pkgs, lib, config, inputs, ... }:

with lib;
let cfg = config.modules.lf;

in {
  options.modules.lf = { enable = mkEnableOption "lf"; };
  config = mkIf cfg.enable {
    xdg.configFile."lf/icons".source = inputs.lf-icons;

    programs.lf = {
      enable = true;
      settings = {
        scrolloff = 999;
        hidden = true;
        smartcase = true;
        icons = true;
      };
      commands = {
        delete = ''
          ''${{
            clear; tput cup $(($(tput lines)/3)); tput bold
              set -f
              printf "%s\n\t" "$fx"
              printf "delete? [y/N] "
              read ans
              [ "$ans" = "y" ] && echo "$fx" | tr ' ' '\ ' | xargs -I{} rm -rf -- "{}"
          }}
        '';
        mkdirWithParent = ''$mkdir -p "$(echo $* | tr ' ' '\ ')" '';
        touchWithParent = ''$mkdir -p "$(dirname "$*")" && touch "$*" '';
        open = "$$EDITOR $f ";
      };
      previewer.source = pkgs.writeShellScript "pv.sh" ''
        #!/bin/sh

        set -c -f
        ifs="$(printf '%b_' '\n')"; ifs="$''${ifs%_}"

        case "$(file --dereference --brief --mime-type -- "$1")" in
          image/* | audio/* | application/octet-stream | video/*) ${pkgs.mediainfo}/bin/mediainfo "$6" ;;
          text/html) ${pkgs.lynx}/bin/lynx -width="$4" -display_charset=utf-8 -dump "$1" ;;
          */pdf) ${pkgs.poppler_utils}/bin/pdftotext "$1" -;;
          application/*zip) ${pkgs.atool}/bin/atool --list -- "$1" ;;
          *opendocument*) ${pkgs.odt2txt}/bin/odt2txt "$1" ;;
          *) bat -p --terminal-width "$(($4-2))" -f "$1" ;;
        esac
        exit 1
      '';
      keybindings = {
        D = "delete";
        U = "!${pkgs.du-dust}/bin/dust";
        R = "!${pkgs.massren}/bin/massren";
        m = "push :mkdirWithParent<space>";
        t = "push :touchWithParent<space>";
        "<enter>" = "open";
        A = "rename"; # at the very end
        c = "push A<c-u>"; # new rename
        I = "push A<c-a>"; # at the very beginning
        i = "push A<a-b><a-b><a-f>"; # before extention
        a = "push A<a-b>"; # after extention
        M = "mark-save";
        s = "!zsh";
      };
    };

  };
}
