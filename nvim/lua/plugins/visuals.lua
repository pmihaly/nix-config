return {
  {
    'shaunsingh/nord.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.nord_disable_background = true;
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
    'lewis6991/gitsigns.nvim',
    event = 'BufReadPost',
    config = function()
      require('gitsigns').setup()
    end
  },
  {
    'echasnovski/mini.starter',
    config = function () require('mini.starter').setup() end,
    version = '*'
  },
}
