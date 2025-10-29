{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

with lib;
let
  cfg = config.modules.shell;
  bookmarksToAliases = attrsets.mapAttrs' (
    name: value: attrsets.nameValuePair "g${name}" "cd ${value}"
  );
in
{
  options.modules.shell = {
    enable = mkEnableOption "shell";
    bookmarks = mkOption {
      default = { };
      type = types.attrs;
    };
    rebuildSwitch = mkOption { type = types.str; };
  };
  config = mkIf cfg.enable {

    modules.persistence = {
      files = [
        ".bash_history"
      ];
      directories = [ ".local/share/direnv" ];
    };

    home.packages = with pkgs; [
      tldr
      wget
      scrub # delete files securely
      gum # pretty shell scripts
      fd # alternative to find
      parallel # xargs but with multiprocessing
      watch # run a command periodically
      ripgrep # basically grep
      killall
      sd # more intuitive search and replace
      choose # frendlier cut
      pup # jq for html
      dogdns # dns client
      yt-dlp
      inputs.nh.packages."${pkgs.system}".default
      (pkgs.writeScriptBin "is-up" ''
        #! ${getExe pkgs.nushell}
        def main [
          service: string # the service to check
        ]: nothing -> bool {
          ${getExe pkgs.tailscale} status --json
            | from json
            | get Peer
            | values
            | where {$service in $in.DNSName}
            | $in.0.Online
          }
      '')
      gnumake
      universal-ctags
    ];

    programs.direnv.enableNushellIntegration = true;

    programs.fzf.enable = true;

    home.sessionPath = [
      "/Users/$USER/.local/bin"
      "/home/$USER/.local/bin"
      "/usr/local/bin"
      "/etc/profiles/per-user/$USER/bin"
    ];

    programs.bash = {
      enable = true;
      shellAliases = rec {
        ns = cfg.rebuildSwitch;
        ncg = "sudo nix-collect-garbage --delete-old";
        n = "nvim";
        c = "cd ~/.nix-config";
        cn = c + "; nvim .";
        p = "cd `find ~/personaldev/ -mindepth 1 -maxdepth 1 | fzf`";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    programs.btop = {
      enable = true;
      settings = {
        theme_background = false;
        true_color = true;
        update_ms = 100;
        vim_keys = true;
      };
    };

    programs.tmux = {
      enable = true;

    };
  };
}
