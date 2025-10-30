{
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.modules.nvim;
in
{
  options.modules.nvim = {
    enable = mkEnableOption "nvim";
  };
  config = mkIf cfg.enable {

    modules.persistence.directories = [
      ".local/share/nvim"
      ".local/share/db-ui"
    ];
    programs.bash.sessionVariables.EDITOR = getExe config.programs.nixvim.build.package;

    programs.nixvim = {
      enable = true;
      plugins = {
        lsp = {
          enable = true;
          servers = {
            basedpyright.enable = true;
            nixd.enable = true;
            gopls.enable = true;
          };
        };
        cmp = {
          enable = true;
          settings = {
            mapping = {
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-d>" = "cmp.mapping.scroll_docs(-4)";
              "<C-e>" = "cmp.mapping.close()";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
            };
            sources = [
              { name = "nvim_lsp"; }
              { name = "nvim_lsp_signature_help"; }
              { name = "buffer"; }
            ];
          };
        };
      };
    };
  };
}
