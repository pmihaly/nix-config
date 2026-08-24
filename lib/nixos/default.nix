{ lib, vars }:
let
  # Tailscale interface (the tailscale module uses the default name).
  # Matching on the interface (rather than source addresses) covers both the
  # IPv4 CGNAT range and whatever ULA prefix this tailnet happens to use.
  tailnetIface = "tailscale0";

  # Restrict the given TCP ports to the Tailscale interface only.
  # Rules are emitted for both firewall backends; each backend applies its
  # own (the other option is defined but unused on that machine).
  # (Loopback is trusted by both backends, so nginx can still proxy to these
  # ports on 127.0.0.1.)
  # IMPORTANT: the port must NOT also be in networking.firewall.allowedTCPPorts:
  # those rules accept any source and are evaluated before these.
  tailnetRules =
    ports:
    {
      # iptables backend (networking.firewall.backend = "iptables").
      # Runs inside firewall-start, where ip46tables() and the nixos-fw /
      # nixos-fw-accept chains already exist. ip46tables covers v4 + v6.
      extraCommands =
        lib.concatStringsSep "\n" (
          lib.map (p: "ip46tables -A nixos-fw -i ${tailnetIface} -p tcp --dport ${builtins.toString p} -j nixos-fw-accept")
          ports
        );

      # nftables backend (inet table: no ip/ip6 family prefix needed).
      extraInputRules =
        lib.concatStringsSep "\n" (
          lib.map (p: "iifname \"${tailnetIface}\" tcp dport { ${builtins.toString p} } accept")
          ports
        );
    };

  mkService =
    {
      subdomain,
      port,
      dashboard ? null,
      extraConfig,
      extraNginxConfigRoot ? { },
      extraNginxConfigLocation ? { },
      bypassAuth ? false,
      # Expose via the public domain: an nginx vhost on
      # ${subdomain}.${publicDomainName} (HTTPS, Let's Encrypt) proxies to the
      # service port on loopback. The service port itself stays tailnet-only.
      # Requires vars.publicDomainName and vars.acmeEmail on this machine.
      public ? false,
    }:
    let
      base = {
        networking.firewall = tailnetRules [ port ];

        services.nginx.virtualHosts."${vars.domainName}".locations."/${subdomain}" = {
          return = "301 http://${vars.domainName}:${toString port}";
        };
      };

      dashboardConfig = lib.mkIf (builtins.isAttrs dashboard) {
        modules.homer.services."${dashboard.category}"."${dashboard.name}" = {
          logo = dashboard.logo;
          url = "http://${vars.domainName}:${toString port}";
        };
      };

      publicConfig = lib.mkIf public {
        services.nginx.virtualHosts."${subdomain}.${vars.publicDomainName}" = {
          # Also becomes the default server, so the apex domain (e.g.
          # skylake.mihaly.codes) serves this service too. nginx -t fails
          # loudly if a second public service is added without deciding what
          # the apex should serve.
          default = true;
          forceSSL = true;
          enableACME = true;
          # Explicit webroot for the HTTP-01 challenge; the ACME module
          # asserts exactly one of webroot/dnsProvider/listenHTTP/s3Bucket
          # and the nginx module forces the cert's webroot to acmeRoot.
          acmeRoot = "/var/lib/acme/acme-challenge";
          locations."/" = {
            proxyPass = "http://127.0.0.1:${builtins.toString port}";
          };
        };

        # Let's Encrypt account + ToS (only pulled in when a service is public).
        security.acme = {
          acceptTerms = true;
          defaults.email = vars.acmeEmail;
        };
      };
    in
    # mkMerge, NOT shallow `//`: `//` would merge mkIf's wrapper attributes
    # (_type/condition/content) into the top level of the result, and the
    # module system (pushDownProperties) would then treat the whole result as
    # a conditional wrapper and keep only its `content` — silently dropping
    # the firewall rules, tailnet vhost and homer entry.
    lib.mkMerge [ base dashboardConfig publicConfig extraConfig ];
  getDockerVersionFromShield =
    githubTags:
    githubTags
    |> builtins.readFile
    |> builtins.fromJSON
    |> (builtins.getAttr "value");
in
{
  inherit mkService getDockerVersionFromShield;
}
