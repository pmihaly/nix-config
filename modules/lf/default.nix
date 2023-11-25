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
      };
      extraConfig = let
        previewer = pkgs.writeShellScriptBin "pv.sh" ''
          file=$1
          w=$2
          h=$3
          x=$4
          y=$5

          if [[ "$( ${pkgs.file}/bin/file -Lb --mime-type "$file")" =~ ^image ]]; then
              ${pkgs.kitty}/bin/kitty +kitten icat --silent --stdin no --transfer-mode file --place "''${w}x''${h}@''${x}x''${y}" "$file" < /dev/null > /dev/tty
              exit 1
          fi

          ${pkgs.pistol}/bin/pistol "$file"
        '';
        cleaner = pkgs.writeShellScriptBin "clean.sh" ''
          ${pkgs.kitty}/bin/kitty +kitten icat --clear --stdin no --silent --transfer-mode file < /dev/null > /dev/tty
        '';
      in ''
        set cleaner ${cleaner}/bin/clean.sh
        set previewer ${previewer}/bin/pv.sh
      '';
    };
  };
}
