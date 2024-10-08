rec {
  domainName = "skylake.anaconda-snapper.ts.net";
  timeZone = "Europe/Budapest";
  persistDir = "/persist";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  rebuildSwitch = "sudo nixos-rebuild switch --flake ~/.nix-config#skylake";
}
