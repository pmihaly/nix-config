{
  pkgs,
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.pinchflat;
  # Public copyparty instance roots ${vars.storage}/Public (served at
  # https://files.${vars.publicDomainName}) with rwmd — a subdirectory here
  # is what the task calls "the yt directory in the public copyparty".
  # Pinchflat writes downloads straight into it, so they appear in the
  # public file browser without any FTP/sync step. The directory must be
  # owned by the pinchflat service user (tmpfiles below), and remains
  # world-readable so the copyparty user can serve it.
  ytDir = "${vars.storage}/Public/yt";
in
{
  options.modules.pinchflat = {
    enable = mkEnableOption "pinchflat (YouTube media manager)";
  };

  config = mkIf cfg.enable (mkService {
    subdomain = "pinchflat";
    port = 8945;

    # Public: https://pinchflat.${publicDomainName} — nginx (Let's Encrypt)
    # proxies to 8945 on loopback. 8945 is otherwise tailnet-only and
    # firewall-closed to the WAN (mkService tailnetRules; pinchflat's own
    # openFirewall stays false). The wildcard A record covers the subdomain.
    public = true;

    dashboard = {
      category = "Media";
      name = "Pinchflat";
      logo = ./pinchflat.png;
    };

    extraConfig = {
      # Native nixpkgs NixOS module (package bundles yt-dlp + apprise).
      # NOT selfhosted: a real SECRET_KEY_BASE comes from the agenix
      # secret below (the module asserts secretsFile != null when
      # selfhosted = false).
      #
      # NOTE (2026-08-30): basic auth (BASIC_AUTH_USERNAME/PASSWORD) was
      # REMOVED at the operator's request — the public UI at
      # pinchflat.${publicDomainName} is now unauthenticated. Trade-off:
      # an open public pinchflat is a free YouTube/bandwidth/disk-abuse
      # vector for anyone on the internet; if that ever becomes a problem,
      # re-add BASIC_AUTH_* to the secret env-file (re-encrypt
      # secrets/server/pinchflat.age) or restrict the public vhost
      # (machines/skylake/PUBLIC-ACCESS.md).
      services.pinchflat = {
        enable = true;
        mediaDir = ytDir;
        secretsFile = config.age.secrets."server/pinchflat".path;
      };

      # agenix secret (env-file): SECRET_KEY_BASE (64+ bytes) only —
      # BASIC_AUTH_USERNAME/PASSWORD were removed 2026-08-30 (see above).
      # `file` defaults to /run/agenix/server/pinchflat; readable by
      # systemd (EnvironmentFile for the pinchflat unit).
      age.secrets."server/pinchflat" = {
        file = ../../../secrets/server/pinchflat.age;
        owner = "pinchflat";
        group = "pinchflat";
        mode = "0400";
      };

      # Create the yt dir (and heal ownership/perms) at every boot. The
      # public copyparty volume root is "${storage}/Public" (0755,
      # copyparty:copyparty) — pinchflat must own the subdir to write into
      # it, and it stays world-readable so the copyparty user serves it.
      systemd.tmpfiles.rules = [
        "d ${ytDir} 0755 pinchflat pinchflat -"
      ];

      # Persist the service's config DB + metadata across reboots. The
      # native module's StateDirectory is /var/lib/pinchflat (tmpfs root),
      # which /persist (env.persistence.${persistDir}) survives.
      environment.persistence.${vars.persistDir} = {
        directories = [ "/var/lib/pinchflat" ];
      };
    };
  });
}
