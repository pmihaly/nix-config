{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.git;
  lazygit = pkgs.lazygit.overrideAttrs (old: {
    src = inputs.lazygit;
  });
in
{
  options.modules.git = {
    enable = mkEnableOption "git";
  };
  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      git
      tig # prettier git tree
    ];

    home.file."${config.xdg.configHome}/git/config".text = generators.toINI { } {
      user = {
        name = "pmihaly";
        email = "misi@pappmihaly.com";
      };
      pull.rebase = true;
      merge.conflictstyle = "zdiff3";
      rebase.autosquash = true;
      rebase.autostash = true;
      push.default = "current";
      push.autoSetupRemote = true;
      rerere.enabled = true;
      transfer.fsckobjects = true;
      fetch.fsckobjects = true;
      receive.fsckObjects = true;
      branch.sort = "-committerdate";

      diff.tool = "difftastic";
      difftool.prompt = false;
      "difftool \"difftastic\"".cmd = ''${pkgs.difftastic}/bin/difft "$LOCAL" "$REMOTE"'';
      pager.difftool = true;
      diff.external = "${pkgs.difftastic}/bin/difft";
    };

    programs.lazygit = {
      enable = true;
      package = lazygit;
      settings = {
        notARepository = "quit";
        disableStartupPopups = true;
        promptToReturnFromSubprocess = false;
        git.paging.externalDiffCommand = "${pkgs.difftastic}/bin/difft --color=always --tab-width=2";
        os.editPreset = "nvim-remote";
        gui.nerdFontsVersion = 3;
        customCommands = [
          rec {
            key = "P";
            command = "git push --force-with-lease";
            context = "global";
            description = command;
            loadingText = "${description}...";
          }
          {
            key = "b";
            command = "tig blame -- {{.SelectedFile.Name}}";
            context = "files";
            description = "blame file at tree";
            subprocess = true;
          }
          {
            key = "b";
            command = "tig blame -- {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
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
            command = "tig {{.SelectedSubCommit.Sha}} -- {{.SelectedCommitFile.Name}}";
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

    programs.zsh = {
      shellAliases = {
        lg = "lazygit";
        dm = "git diff origin/master HEAD";
      };
    };
  };
}
