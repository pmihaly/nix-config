rec {
  domainName = "skylake.anaconda-snapper.ts.net";
  timeZone = "Europe/Budapest";
  persistDir = "/persist";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  rebuildSwitch = "nh os switch ~/.nix-config --hostname skylake -- --option extra-experimental-features pipe-operators";
}
