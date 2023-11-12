{ pkgs, lib, config, ... }:

with lib;
let cfg = config.modules.zsh;

in {
  options.modules.zsh = { enable = mkEnableOption "zsh"; };
  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      git
# httpie
        curlie # httpie but with --curl
        tldr
        yq-go
        jq
        jiq # interactive jq
        wget
        scrub # delete files securely
        duf # prettier lsblk
        gum # pretty shell scripts
        fd # alternative to find
        parallel # xargs but with multiprocessing
        watch # run a command periodically
        gnumake
        lsof # used by kbp alias - Lists open files and the corresponding processes
        qrencode # str to qr code
        ripgrep # basically grep
        killall
        sd # more intuitive search and replace
        du-dust # prettier du -sh
        choose # frendlier cut
        pup # jq for html
        nushellFull # structured data manipulation - replaces jq, jiq and yq
        eza # pretty ls
        ];

    programs.bat = {
      enable = true;
      config = {
        theme = "Nord";
      };
    };

    programs.fzf = {
      enable = true;
      tmux.enableShellIntegration = true;
      enableZshIntegration = true;
    };


    home.sessionPath = [
      "/Users/$USER/.local/bin"
        "/home/$USER/.local/bin"
        "/usr/local/bin"
        "/etc/profiles/per-user/$USER/bin"
        "/run/current-system/sw/bin/"
    ];


    programs.zsh = {
      enable = true;
      initExtra =
        let iglooPrompt = builtins.concatStringsSep "\n" [
        "export IGLOO_ZSH_PROMPT_THEME_HIDE_TIME=true"
          (builtins.readFile
           (builtins.fetchurl
            {
            url = "https://raw.githubusercontent.com/git/git/4ca12e10e6fbda68adcb32e78497dc261e94734d/contrib/completion/git-prompt.sh";
            sha256 = "0rjwxf1vfkynjqns6drhbrfv7358zyhhx5j4zgawm25qwza4xggi";
            }))
      (builtins.readFile
       (builtins.fetchurl
        {
        url = "https://raw.githubusercontent.com/arcticicestudio/igloo/18b735009f2baa29e3bbe1323a1fc2082f88b393/snowblocks/zsh/lib/themes/igloo.zsh";
        sha256 = "17ln78ww66mg1k2yljpap74rf6fjjiw818x4pc2d5l6yjqgv8wfl";
        }))
        ];
        in
          builtins.concatStringsSep "\n"
          [
          ''
            autoload -U promptinit; promptinit

            set -o vi

            zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

            autoload -z edit-command-line
            zle -N edit-command-line
            bindkey "^X" edit-command-line

            [ -f ~/.zshrc_work ] && . ~/.zshrc_work
            ''
              iglooPrompt
          ];
        enableCompletion = true;
        completionInit = ''
          autoload bashcompinit && bashcompinit
          autoload -Uz compinit && compinit

          hash kubectl 2>/dev/null && . <(kubectl completion zsh)
          hash k3d 2>/dev/null && . <(k3d completion zsh)
          hash yq 2>/dev/null && . <(yq shell-completion zsh)

          complete -C 'aws_completer' aws
          '';

        syntaxHighlighting = {
          enable = true;
          styles = {
            main = "";
            brackets = "";
          };
        };
        enableAutosuggestions = true;
        autocd = true;
        history = {
          ignoreDups = true;
        };
        shellAliases = {
          ls = "eza -lah $([ -d .git ] && echo '--git')";
          cat = "bat";
          d = "cd $(find ~/lensadev -maxdepth 1 -type d | fzf)";
          dn = "d && nvim";
          p = "cd $(find ~/personaldev -maxdepth 1 -type d | fzf)";
          pn = "p && nvim";
          o = "cd ~/Sync/org";
          on = "o && (fd \"^.*\.org$\" | fzf | xargs nvim)";
          ld = "lazydocker";
          ms = "pushd ~/.nix-config ; make switch-mac ; popd";
          mp = "pushd ~/.nix-config ; sudo make switch-pc ; popd";
          nr = "sudo nix-store --verify --check-contents --repair";
          ns = "nix search nixpkgs";
          ncg = "nix-collect-garbage --delete-old";
          nsh = "function _f() { nix-shell -p $* --run zsh }; _f";
          nshr = "function _f() { program=$1; shift; nix-shell -p $program --run $@ }; _f";
          cn = "cd ~/.nix-config && nvim";
          c = "cd ~/.nix-config";
          thokr = "thokr --full-sentences 20";
          kbp = "sudo touch /dev/null ; lsof -iTCP -sTCP:LISTEN -n -P +c0 | awk 'NR>1{gsub(/.*:/,\"\",$9); print $9, $1, $2}' | fzf --multi --with-nth=1,2 --header='Select processes to be killed' | cut -d' ' -f3 | xargs kill -9";
          kaf = "kubectl apply -f";
          kak = "function _kak() { kubectl kustomize --enable-helm \"$1\" | kubectl apply -f -; }; _kak";
          pis = "function _pis() { kubectl kustomize --enable-helm \"$1\" | kubectl delete -f -; }; _pis";
          urlencode = "jq -sRr @uri";
          dselect = "docker ps --format '{{.ID}}\t{{.Image}}' | fzf --with-nth 2 | cut -f1";
          dim = "dselect | tee >(tr -d '\n' | pbcopy)";
          dl = "dselect | xargs docker logs -f";
          dex = "container=$(dselect); docker exec -it \"\$container\" \"\${@:-bash}\"";
          ticket = "git branch --show-current | grep -oE \"[A-Z]+-[0-9]+\"";
          revo = "function _f() { revolut.sh ~/Sync/finances.yaml | vipe --suffix yaml | envelopes > ~/Sync/finances.yaml }; _f";
          fin = "$EDITOR ~/Sync/finances.yaml";
          nb = "newsboat";
          qr = "qrencode -t ansiutf8";
          sr = "function _f() { fd --type file --exec sd \"$1\" \"$2\" }; _f";
          du = "dust";
          lsblk = "duf";
          http = "curlie";
          wttr = "http wttr.in/budapest";
        };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };

  };
}
