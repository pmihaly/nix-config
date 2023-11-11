return {
  {
    'shaunsingh/nord.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      vim.g.nord_disable_background = true;
      vim.g.nord_italic = false;
      vim.cmd([[colorscheme nord]])
    end,
  },
  {
    'lukas-reineke/indent-blankline.nvim',
    event = 'BufReadPost',
    main = 'ibl',
    opts = {}
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
