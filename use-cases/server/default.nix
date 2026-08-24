{
  platform,
  lib,
  vars,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.server;
in
optionalAttrs platform.isLinux {
  options.modules.server = {
    enable = mkEnableOption "server";
  };
  imports = [ ../../modules/nixos ];
  config = mkIf cfg.enable (mkMerge [

    {
      users.users.${vars.username} = {
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9W5fVVxjEIo66iLCDfwxHh0IQ6r9R3J/Fq5b9LWNM mihaly.papp@mihalypapp-MacBook-Pro"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE82BvyY3AfskGM3QlHEpjG7N6FomVAI21MbkilGBOHC misi@aesop"
        ];
      };
    }

    {
      users.groups.multimedia.members = [ "${vars.username}" ];
      users.groups.backup.members = [ "${vars.username}" ];
    }

    {
      modules = {
        nginx.enable = true;
        jellyfin.enable = true;
        homer.enable = true;
        deluge.enable = true;
        paperless.enable = true;
        immich.enable = true;
        tailscale.enable = true;
        it-tools.enable = true;
        copyparty.enable = true;
      };
    }

    {
      # --- IPv4 FORWARD hardening: keep podman-published container ports
      # unreachable from the public internet.
      #
      # Why: podman/netavark implements published ports with DNAT, so traffic
      # to those host ports is *forwarded* to the podman bridge; the NixOS
      # INPUT firewall (nixos-fw) never sees it, and NixOS leaves the FORWARD
      # policy at ACCEPT. Result: 0.0.0.0:<published> (jellyfin 8096, homer
      # 8080, immich 2283, ...) was reachable from the WAN. Verified on
      # 2026-08-24: the FORWARD policy accept counter was counting scan
      # traffic (270 pkts), and none of the chains had a rule covering
      # WAN->published ports.
      #
      # What is allowed (IPv4 only — the IPv6 policy is deliberately left
      # untouched; bridge NDP/multicast and tailscale v6 flows rely on it):
      #   -i tailscale0      tailnet clients can still reach published ports
      #                       (ts-forward already accepts these; kept explicit
      #                       and self-documenting)
      #   -i lo              locally generated traffic that gets DNATed to a
      #                       container (host services talking to published
      #                       ports); lo cannot be spoofed and can only reach
      #                       the bridge, never the WAN
      #   RELATED,ESTABLISHED  return traffic for all of the above and for
      #                       container egress
      #   policy DROP        everything else is silently dropped (stealth,
      #                       no RST), i.e. WAN -> published container ports
      #
      # Container egress (bridge -> WAN) is unaffected: netavark inserts its
      # NETAVARK_FORWARD chain at the *head* of FORWARD on every container
      # start, and it accepts -s <bridge-subnet> unconditionally, before any
      # rule below is evaluated.
      #
      # The -D preambles make re-runs idempotent: firewall-start never
      # flushes the built-in FORWARD chain on a system switch, so without
      # them the rules would accumulate on every deploy.
      #
      # Note: extraCommands only takes effect with the iptables firewall
      # backend (the default). If the backend is ever switched to nftables,
      # this needs porting to networking.nftables or a separate activation.
      networking.firewall.extraCommands = ''
        iptables -w -D FORWARD -i tailscale0 -j ACCEPT 2>/dev/null || true
        iptables -w -D FORWARD -i lo -j ACCEPT 2>/dev/null || true
        iptables -w -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
        iptables -w -A FORWARD -i tailscale0 -j ACCEPT
        iptables -w -A FORWARD -i lo -j ACCEPT
        iptables -w -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
        iptables -w -P FORWARD DROP
      '';
    }
  ]);
}
