# work machine setup

1. install nix [https://github.com/DeterminateSystems/nix-installer]()
1. install developer tools `xcode-select --install`
1. add full disk permission to terminal and nix
1. send over and open keepassxc pas file -- this adds ssh key into ssh agent
1. download repo `nix run nixpkgs#git clone git@github.com:pmihaly/nix-config ~/.nix-config`
1. fill in workvars.json
1. `nix run nix-darwin#darwin-rebuild switch --impure --flake ~/.nix-config#mac` (enable `|>` pipes)
1. turn off secure keyboard entry from kitty in kitty menu bar
