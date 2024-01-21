{
  domainName = "skylake.mihaly.codes";
  timeZone = "Europe/Berlin";
  acmeEmail = "skylake-certs@mihaly.codes";
  serviceConfig = "/persist/opt/skylake-services";
  storage = "/persist/opt/skylake-storage";
  username = "misi";
  duckdnsDomainName = "mishmesh.duckdns.org";
  bookmarks = (import ../common/vars.nix).bookmarks;
}
