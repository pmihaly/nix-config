{ pkgs, config, ... }:
{
  imports = [
    ./vscode
    ./firefox
    ./nvim
  ];
}
