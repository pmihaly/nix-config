return {
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = 'BufReadPost',
    dependencies = {
      'nvim-treesitter'
    },
  },
  {
    'LhKipp/nvim-nu',
    event = 'BufReadPost',
    build = ':TSInstall nu',
    dependencies = {
      'nvim-treesitter'
    },
  },
  {
    'echasnovski/mini.ai',
    event = 'VeryLazy',
    dependencies = {
      {
        'nvim-treesitter/nvim-treesitter-textobjects',
        init = function()
          require('lazy.core.loader').disable_rtp_plugin('nvim-treesitter-textobjects')
        end,
      },
    },
    opts = function()
      local ai = require('mini.ai')
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({
            a = { '@block.outer', '@conditional.outer', '@loop.outer' },
            i = { '@block.inner', '@conditional.inner', '@loop.inner' },
          }, {}),
          f = ai.gen_spec.treesitter({ a = '@function.outer', i = '@function.inner' }, {}),
          c = ai.gen_spec.treesitter({ a = '@class.outer', i = '@class.inner' }, {}),
        },
      }
    end,
    config = function(_, opts)
      local ai = require('mini.ai')
      ai.setup(opts)
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    version = false,
    build = ':TSUpdate',
    event = 'BufReadPost',
    keys = {
      { '<c-space>', desc = 'Increment selection' },
      { '<bs>', desc = 'Schrink selection', mode = 'x' },
    },
    opts = {
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = {'org'},
      },
      indent = { enable = true },
      context_commentstring = { enable = true, enable_autocmd = false },
      ensure_installed = {
        'bash',
        'html',
        'javascript',
        'json',
        'kotlin',
        'lua',
        'markdown_inline',
        'nix',
        'python',
        'query',
        'regex',
        'terraform',
        'tsx',
        'typescript',
        'vim',
        'yaml',
        'org',
        'c',
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = '<C-space>',
          node_incremental = '<C-space>',
          scope_incremental = '<nop>',
          node_decremental = '<bs>',
        },
      },
    },
    config = function(_, opts)
      require('nvim-treesitter.configs').setup(opts)
    end,
  },
}


