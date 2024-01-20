return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      transparent_background = true,
    },
    config = function(p, opts)
      require('catppuccin').setup(opts)
      vim.cmd([[colorscheme catppuccin-frappe]])
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    event = 'BufReadPost',
    main = 'ibl',
    opts = {
      scope = { enabled = false },
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
    config = function() require('mini.starter').setup() end,
    version = '*'
  },
}
