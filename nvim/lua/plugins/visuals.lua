return {
  {
    'folke/tokyonight.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme tokyonight-moon]])
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
    }
  },
  {
    'xiyaowong/nvim-transparent',
    opts = {
      enable = true,
      extra_groups = {
        'DiagnosticVirtualTextWarn',
        'DiagnosticVirtualTextError',
        'DiagnosticVirtualTextHint',
        'DiagnosticVirtualTextInfo',
        'TelescopeNormal',
      }
    }
  },
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end
  },
}
