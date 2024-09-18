{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.yazi;
  bookmarksToYaziKeybindings = attrsets.mapAttrsToList (
    name: value: {
      on = [ "g" ] ++ (strings.stringToCharacters name);
      run = "cd ${value}";
    }
  );
in
{
  options.modules.yazi = {
    enable = mkEnableOption "yazi";
    bookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
  };
  config = mkIf cfg.enable {
    programs.zsh.shellAliases.ya = "yy"; # idk where "yy" zsh function comes from
    programs.yazi = {
      enable = true;
      settings = {
        manager = {
          scrolloff = 200;
          show_hidden = true;
          show_symlink = false;
          sort_dir_first = true;
        };
        opener = {
          edit = [
            {
              run = "${config.programs.zsh.localVariables.EDITOR} \"$@\"";
              block = true;
            }
          ];
          play = [
            {
              run = "mpv \"$@\"";
              orphan = true;
            }
          ];
        };
      };
      keymap.manager.prepend_keymap = [
        {
          on = [ "z" ];
          run = "shell --block --confirm \"${pkgs.unzip}/bin/unzip $0\"";
        }
      ] ++ (bookmarksToYaziKeybindings cfg.bookmarks);
      theme = { };
    };
  };
}
