{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.git;

in {
  options.modules.git = { enable = mkEnableOption "git"; };
  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      git
      tig # prettier git tree
    ];

    home.file."${config.xdg.configHome}/git/config".text =
      generators.toINI { } {
        user = {
          name = "pmihaly";
          email = "misi@pappmihaly.com";
        };
        pull.rebase = true;
      };

    programs.lazygit = {
      enable = true;
      settings = {
        notARepository = "quit";
        disableStartupPopups = true;
        customCommands = [
          {
            key = "b";
            command = "tig blame -- {{.SelectedFile.Name}}";
            context = "files";
            description = "blame file at tree";
            subprocess = true;
          }
          {
            key = "b";
            command =
              "tig blame -- {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
            context = "commitFiles";
            description = "blame file at revision";
            subprocess = true;
          }
          {
            key = "B";
            command = "tig blame -- {{.SelectedCommitFile.Name}}";
            context = "commitFiles";
            description = "blame file at tree";
            subprocess = true;
          }
          {
            key = "t";
            command =
              "tig {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
            context = "commitFiles";
            description = "tig file (history of commits affecting file)";
            subprocess = true;
          }
          {
            key = "t";
            command = "tig -- {{.SelectedFile.Name}}";
            context = "files";
            description = "tig file (history of commits affecting file)";
            subprocess = true;
          }
        ];
      };
    };

    programs.zsh = { shellAliases = { lg = "lazygit"; }; };

  };
}
