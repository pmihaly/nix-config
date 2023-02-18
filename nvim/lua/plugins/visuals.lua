return {
  {
    'shaunsingh/nord.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme nord]])
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    event = 'BufReadPost',
    opts = {
      char = '┊',
      show_trailing_blankline_indent = false,
    }
  },
  {
    'xiyaowong/nvim-transparent',
    event = 'VeryLazy',
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
    event = 'BufReadPost',
    config = function()
      require('gitsigns').setup()
    end
  },
}
