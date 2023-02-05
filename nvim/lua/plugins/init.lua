return {

  {
    'numToStr/Comment.nvim',
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
    'kylechui/nvim-surround',
    config = true,
  },
  'wellle/targets.vim',
  {
    'windwp/nvim-autopairs',
    config = true,
  },
}
