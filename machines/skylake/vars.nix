rec {
  domainName = "skylake.anaconda-snapper.ts.net";
  timeZone = "Europe/Helsinki";
  persistDir = "/persist";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  rebuildSwitch = "nh os switch ~/.nix-config --hostname skylake";
}
