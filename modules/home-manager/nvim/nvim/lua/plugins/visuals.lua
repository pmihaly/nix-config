return {
  {
    'catppuccin/nvim',
    name = 'catppuccin',
    priority = 1000,
    opts = {
      transparent_background = true,
    },
    config = function(p, opts)
      require("catppuccin").setup(opts)
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
  {
    'lukas-reineke/headlines.nvim',
    ft = { 'markdown' },
    dependencies = 'nvim-treesitter/nvim-treesitter',
    config = {
      markdown = {
        headline_highlights = {
          'Headline1',
          'Headline2',
          'Headline3',
          'Headline4',
          'Headline5',
          'Headline6',
        },
        codeblock_highlight = 'CodeBlock',
        dash_highlight = 'Dash',
        quote_highlight = 'Quote',
      },
    }
  }
}
