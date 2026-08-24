rec {
  domainName = "skylake.anaconda-snapper.ts.net";
  # Public DNS (A records for skylake.mihaly.codes and *.skylake.mihaly.codes)
  publicDomainName = "skylake.mihaly.codes";
  # Contact address for Let's Encrypt account creation (security.acme)
  acmeEmail = "mihaly@mihaly.codes";
  timeZone = "Europe/Helsinki";
  persistDir = "/persist";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  rebuildSwitch = "nh os switch ~/.nix-config --hostname skylake";
}
