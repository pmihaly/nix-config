{
  domainName = "skylake.mihaly.codes";
  timeZone = "Europe/Berlin";
  acmeEmail = "skylake-certs@mihaly.codes";
  serviceConfig = "/persist/opt/skylake-services";
  storage = "/persist/opt/skylake-storage";
  username = "misi";
  duckdnsDomainName = "mishmesh.duckdns.org";
  bookmarks = rec {
    h = "~";
    d = "~/Downloads";
    p = "~/personaldev";
    w = "~/lensadev";
    o = "~/Sync/org";
    n = "~/.nix-config";
    fio = p + "/finances/import/otp/in";
    fir = p + "/finances/import/revolut/in";
    fiw = p + "/finances/import/wise/in";
  };
}
