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
      # Claim the apex domain: make the public vhost the default_server, so
      # the bare domain (e.g. skylake.mihaly.codes) serves this service too.
      # Only ONE service per machine may set this — nginx refuses to start
      # with two default servers on the same listen socket. Ignored unless
      # public = true.
      apex ? false,
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
          # Only with apex = true does this vhost become the default_server
          # and serve the apex domain (e.g. skylake.mihaly.codes) itself.
          # nginx -t fails loudly if two vhosts claim the apex.
          default = apex;
          # The Let's Encrypt cert for this vhost covers serverName +
          # serverAliases. With apex = true, add the bare domain as an alias
          # so the apex actually gets a matching cert (without this, https
          # on the apex would fail hostname verification).
          serverAliases = lib.optional apex vars.publicDomainName;
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

        # The HTTP-01 webroot must exist before lego runs. The acme module
        # ships its own tmpfiles rule for it (10-acme.conf, acme:acme 0755),
        # but on skylake the webroot was nonetheless missing after the
        # 2026-08-23 migration (spurious tmpfiles failure + first-activation
        # race with the /var/lib/acme mount; see
        # machines/skylake/PUBLIC-ACCESS.md). This rule in 00-nixos.conf is
        # processed *before* 10-acme.conf and is version-agnostic: `d`
        # creates the dir if missing, `z` heals ownership to acme:nginx 0750
        # if it exists (lego writes the token as acme, nginx serves it).
        # Idempotent, self-healing after a /persist rebuild, survives the
        # tmpfs root.
        systemd.tmpfiles.rules = [
          "d /var/lib/acme/acme-challenge 0750 acme nginx -"
          "z /var/lib/acme/acme-challenge 0750 acme nginx -"
        ];
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
  inherit mkService getDockerVersionFromShield tailnetRules;
}
