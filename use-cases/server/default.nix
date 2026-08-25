{
  platform,
  lib,
  vars,
  config,
  pkgs,
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
      # policy at ACCEPT. Result: 0.0.0.0:<published> (homer 8080, immich
      # 2283, ...) was reachable from the WAN. Verified on
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
      # --- Application mechanism ------------------------------------------------
      #
      # The rules below are installed by a dedicated oneshot unit
      # (fw-forward.service), NOT by networking.firewall.extraCommands.
      #
      # Reason: with nixos-unstable @ 56c02bc the firewall *unit* silently
      # ignores extraCommands — adding the rules to extraCommands changed the
      # evaluated option (visible via nix eval) but the generated
      # unit-firewall.service kept the exact same store hash as before
      # (sjgp5aks35fwncdpqj34djkdr6i83j98), i.e. the rules never reached the
      # unit. Same class of silent config drop that cce82a7 fixed in mkService.
      # A plain systemd oneshot cannot be dropped by a firewall-backend quirk:
      # it is version-agnostic and shows up in `systemctl` like anything else.
      #
      # The extraCommands copy is kept as well: harmless if the module keeps
      # dropping it (the -D preambles make double application idempotent) and
      # it becomes the primary mechanism if a future nixpkgs honours it.
      #
      # Ordering: the unit runs in sysinit right after firewall.service.
      # firewall-stop only removes nixos-fw/nixos-drop rules and never touches
      # the FORWARD chain or policy, so the rules survive firewall restarts
      # across system switches; they are re-applied (idempotently) at boot.
      #
      # Note: iptables-only (IPv4). If the firewall backend is ever switched
      # to nftables, port this to networking.nftables or an nft oneshot.

      systemd.services.fw-forward = {
        description = "FORWARD chain hardening (podman published ports off the WAN)";
        wantedBy = [ "sysinit.target" ];
        after = [ "network-pre.target" "firewall.service" ];
        script = ''
          iptables -w -D FORWARD -i tailscale0 -j ACCEPT 2>/dev/null || true
          iptables -w -D FORWARD -i lo -j ACCEPT 2>/dev/null || true
          iptables -w -D FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
          iptables -w -A FORWARD -i tailscale0 -j ACCEPT
          iptables -w -A FORWARD -i lo -j ACCEPT
          iptables -w -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
          iptables -w -P FORWARD DROP
        '';
        environment.PATH = lib.mkForce (lib.makeBinPath [ pkgs.iptables ]);
        serviceConfig.RemainAfterExit = true;
      };

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
