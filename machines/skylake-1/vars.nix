rec {
  domainName = "skylake-1.anaconda-snapper.ts.net";
  timeZone = "Europe/Helsinki";
  persistDir = "/persist";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  rebuildSwitch = "nh os switch ~/.nix-config --hostname skylake-1 -- --option extra-experimental-features pipe-operators";
}
