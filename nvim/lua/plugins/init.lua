return {
  {
    'numToStr/Comment.nvim',
    event = 'VeryLazy',
    config = true,
  },
  'tpope/vim-sleuth',
  {
    'ahmedkhalf/project.nvim',
    event = 'VeryLazy',
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
    init = function() vim.g.mkdp_filetypes = { "markdown" } end
  }
}
