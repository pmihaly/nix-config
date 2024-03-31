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
    cmd = { 'MarkdownPreviewToggle', 'MarkdownPreview', 'MarkdownPreviewStop' },
    keys = {
      { '<leader>mp', function() vim.api.nvim_command('MarkdownPreview') end, mode = 'n'},
    },
    ft = { 'markdown' },
    build = function() vim.fn['mkdp#util#install']() end,
    init = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_theme = 'light'
    end,
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
      vim.g.copilot_filetypes = {
        VimspectorPrompt = false,
        markdown = true,
        yaml = true
      }
    end,
  },
  {
    'michaelb/sniprun',
    branch = 'master',
    keys = {
      { '<leader>r', function() require'sniprun'.run('n') end, mode = 'n'},
      { '<leader>r', function() require'sniprun'.run('v') end, mode = 'v'},
    },

    build = 'sh install.sh',

    config = function()
      require('sniprun').setup({
      -- your options
      })
    end,
  },
}
