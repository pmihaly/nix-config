rec {
  domainName = "skylake.mihaly.codes";
  timeZone = "Europe/Berlin";
  persistDir = "/persist";
  acmeEmail = "skylake-certs@mihaly.codes";
  serviceConfig = "${persistDir}/opt/skylake-services";
  storage = "${persistDir}/opt/skylake-storage";
  username = "misi";
  duckdnsDomainName = "mishmesh.duckdns.org";
}
