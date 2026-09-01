{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.syncthing;

  # Syncthing's own state (config.xml + device cert/key + folder DB)lane
  # payload. /persist (vars.persistDir) outlives a host rebuild;vars.serviceConfig
  # is IN the restic include list (see the `backup` module set in
  # machines/skylake/default.nix), so the state is both persisted and backed up.
  dataDir = "${vars.serviceConfig}/syncthing";

  # Web GUI port (tailnet-only, fronted by the nginx redirect at /syncthing).
  guiPort = 8384;
in
{
  options.modules.syncthing = {
    enable = mkEnableOption "Syncthing (self-hosted file sync)";
  };

  config = mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      # Run as the machine owner:the historic datadir (and its 600-mode
      # config.xml/certs) is owned by ${vars.username}, and the sync folder
      # destinations share his UID. A dedicated `syncthing` system user
      # would have to chown an existing state -- avoid that.
      user = vars.username;
      group = vars.username;

      # The datadir uses the legacy flat layout (config + db + keys all in
      # one dir) rather than the post-19.03 ${dataDir}/.config/syncthing
      # split. Match it explicitly so an existing install keeps its identity.
      inherit dataDir;
      configDir = dataDir;
      databaseDir = dataDir;

      # Gui bound to all interfaces so the nginx redirect (and any tailnet
      # device) can reach it;the WAN cannot (firewall rule below).
      guiAddress = "0.0.0.0:${builtins.toString guiPort}";

      # NixOS's openDefaultPorts would open 22000/tcp+udp and 21027/udp to
      # ANY source -- which violates the tailnet-only policy and would trip the
      # tailnetRules guard in lib/nixos/default.nix (a port can't be in both
      # allowedTCPPorts and a tailnet rule)? Firewall explicitly below instead.

      openDefaultPorts = false;
    };

    # Create the datadir if missing (purged datadir, fresh node)? No `z`
    # heal:forcing ownership on an existing install would claim files the
    # operator may have chowned differently (e.g. a service user).
    systemd.tmpfiles.rules = [
      "d ${dataDir} 0700 ${vars.username} ${vars.username} -"
    ];

    # Tailnet-only reachability. skylake's WAN input policy is default-DROP;
    # only the tailscale interface may reach these ports. Mirrors the
    # `tailnetRules` helper (lib/nixos/default.nix) but emits the UDP rules the
    # helper doesn't produce. (The helper's TCP rule and the `a port must not
    # be in allowedTCPPorts` guard is documentedin lib;openDefaultPorts
    # is off above so no conflict.)
    networking.firewall = {
      extraCommands = lib.concatStringsSep "\n" [
        "ip46tables -A nixos-fw -i tailscale0 -p tcp --dport ${builtins.toString guiPort} -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p tcp --dport 22000 -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p udp --dport 22000 -j nixos-fw-accept"
        "ip46tables -A nixos-fw -i tailscale0 -p udp --dport 21027 -j nixos-fw-accept"
      ];
      extraInputRules = lib.concatStringsSep "\n" [
        "iifname \"tailscale0\" tcp dport { ${builtins.toString guiPort} 22000 } accept"
        "iifname \"tailscale0\" udp dport { 22000 21027 } accept"
      ];
    };

    # GUI reachable at http://${vars.domainName}/syncthing (tailnet only);
    # nginx 301s the browser to the :8384 GUI on the tailnet. Same redirect
    # mkService (lib/nixos/default.nix) puts in place for internal services.

    services.nginx.virtualHosts."${vars.domainName}".locations."/syncthing" = {
      return = "301 http://${vars.domainName}:${builtins.toString guiPort}";
    };
  };
}
