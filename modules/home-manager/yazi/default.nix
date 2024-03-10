{ lib, config, ... }:

with lib;
let
  cfg = config.modules.yazi;
  bookmarksToYaziKeybindings = attrsets.mapAttrsToList (name: value: {
    on = [ "g" ] ++ (strings.stringToCharacters name);
    exec = "cd ${value}";
  });

in {
  options.modules.yazi = {
    enable = mkEnableOption "yazi";
    bookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
  };
  config = mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      settings = {
        manager = {
          scrolloff = 200;
          show_hidden = true;
          show_symlink = false;
          sort_dir_first = true;
        };
      };
      keymap.manager.prepend_keymap = bookmarksToYaziKeybindings cfg.bookmarks;
      theme = { };
    };
  };
}