{
  lib,
  config,
  vars,
  ...
}:

with lib;
let
  cfg = config.modules.nginx;
in
{
  options.modules.nginx = {
    enable = mkEnableOption "nginx";
  };
  config = mkIf cfg.enable {

    services.nginx = {
      enable = true;

      virtualHosts."${vars.domainName}".globalRedirect = "${vars.domainName}/homer";

      experimentalZstdSettings = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedBrotliSettings = true;
    };

    networking.firewall = {
      enable = true;
      # Web ports only. SSH is deliberately NOT opened here: on skylake it is
      # tailnet-only (machines/skylake/default.nix); on desktops
      # services.openssh.openFirewall (shell use-case) still exposes it.
      allowedTCPPorts = [
        80
        443
      ];
    };
  };
}
