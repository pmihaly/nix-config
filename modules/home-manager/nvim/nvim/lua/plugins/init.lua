return {
  {
    'numToStr/Comment.nvim',
    event = 'VeryLazy',
    config = true,
  },
  'tpope/vim-sleuth',
  {
    'ahmedkhalf/project.nvim',
    config = function()
      require('project_nvim').setup {
        ignore_lsp = { 'sumneko_lua' }
      }
    end
  },
  {
    'Eandrju/cellular-automaton.nvim',
    keys = {
      { '<leader>mr', function() vim.api.nvim_command('CellularAutomaton make_it_rain') end, mode = 'n'},
    }
  },
  {
    'wellle/targets.vim',
    event = 'VeryLazy',
  },
  {
    'echasnovski/mini.pairs',
    version = false,
    event = 'VeryLazy',
    config = function () require('mini.pairs').setup() end
  },
  {
    'echasnovski/mini.surround',
    version = false,
    event = 'VeryLazy',
    config = function () require('mini.surround').setup() end
  },
  {
    'iamcco/markdown-preview.nvim',
    ft = { "markdown" },
    build = 'cd app && npm install',
    keys = {
      { '<leader>mp', function() vim.api.nvim_command('MarkdownPreview') end, mode = 'n'},
    },
    init = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_theme = 'light'
    end
  },
  {
    'folke/which-key.nvim',
    config = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
      require('which-key').setup({ })
    end,
  },
  {
    'github/copilot.vim',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      vim.g.copilot_filetypes = { VimspectorPrompt = false }
    end,
  }
}
