{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = config.modules.music-production;
  lspPlugins = pkgs.callPackage ./lsp-plugins-darwin.nix { };
  vital = pkgs.callPackage ./vital-darwin.nix { };
in
{
  options.modules.music-production.enable = lib.mkEnableOption "music-production";

  config = lib.mkIf cfg.enable {
    home-manager.users.${vars.username} = { lib, ... }: {
      home.activation.ardourLastTweaked = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
        run ${pkgs.python3}/bin/python ${./install_ardour_scripts.py} \
          --config "$HOME/Library/Preferences/Ardour9" \
          --scripts "$HOME/Library/Preferences/Ardour9/scripts" \
          --defaults "${pkgs.ardour}/Applications/Ardour9.app/Contents/Resources/ardour.keys" \
          --lua ${pkgs.lua5_3}/bin/lua
      '';
      home.file = {
        "Library/Preferences/Ardour9/scripts/last_tweaked_monitor.lua".source =
          ./scripts/last_tweaked_monitor.lua;
        "Library/Preferences/Ardour9/scripts/show_last_tweaked.lua".source =
          ./scripts/show_last_tweaked.lua;
        "Library/Preferences/Ardour9/scripts/test_last_touched_tracker.lua".source =
          ./scripts/test_last_touched_tracker.lua;
        "Library/Preferences/Ardour9/scripts/test_binding_probe.lua".source =
          ./scripts/test_binding_probe.lua;
        "Library/Audio/Plug-Ins/VST3/Vital.vst3".source = "${vital}/lib/VST3/Vital.vst3";
        "Library/Audio/Plug-Ins/VST/Vital.vst".source = "${vital}/lib/VST/Vital.vst";
        "Library/Audio/Plug-Ins/Components/Vital.component".source =
          "${vital}/lib/Components/Vital.component";
        "Library/Audio/Plug-Ins/CLAP/Vital.clap".source = "${vital}/lib/CLAP/Vital.clap";
        "Library/Audio/Plug-Ins/LV2/lsp-plugins.lv2".source = "${lspPlugins}/lib/LV2/lsp-plugins.lv2";
        "Library/Audio/Plug-Ins/VST3/lsp-plugins.vst3".source = "${lspPlugins}/lib/VST3/lsp-plugins.vst3";
        "Library/Audio/Plug-Ins/CLAP" = {
          source = "${lspPlugins}/lib/CLAP";
          recursive = true;
        };
      };
    };
  };
}
