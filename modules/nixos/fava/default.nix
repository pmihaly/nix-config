{ lib, config, vars, ... }:

with lib;
let cfg = config.modules.my-fava;

in {
  imports = [ ./fava.nix ];
  options.modules.my-fava = { enable = mkEnableOption "my-fava"; };
  config = mkIf cfg.enable (mkService {
    subdomain = "fava";
    port = 5000;
    dashboard = {
      category = "Finances";
      name = "Fava";
      logo = ./fava.png;
    };
    extraConfig.modules.fava = {
      enable = true;
      beanCountFiles = [ "${vars.storage}/Services/Fava/ledger.beancount" ];
      openFirewall = true;
    };
  });
}
