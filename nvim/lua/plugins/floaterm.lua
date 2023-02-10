return {
  {
    'voldikss/vim-floaterm',
    keys = {
      { '<leader>;', function() vim.api.nvim_command('FloatermToggle') end, mode = 'n'},
      { '<leader>;', function() vim.api.nvim_command('FloatermToggle') end, mode = 't'},

      { '<leader>v', function() vim.api.nvim_command('FloatermNew --autoclose=2 lazygit') end, mode = 'n'},
      { '<leader>f', function() vim.api.nvim_command('FloatermNew --autoclose=2 lf') end, mode = 'n'},
    },
    init = function()
      vim.g.floaterm_width = 160
      vim.g.floaterm_height = 50
      vim.g.floaterm_title = false
      vim.g.floaterm_opener = 'edit'
    end
  }
}
