return {
  {
    'voldikss/vim-floaterm',
    keys = {
      { '<leader>;', function() vim.api.nvim_command('FloatermToggle') end, mode = 'n'},
      { '<leader>;', function() vim.api.nvim_command('FloatermToggle') end, mode = 't'},

      { '<leader>,', function() vim.api.nvim_command('FloatermToggle') end, mode = 'n'},
      { '<leader>,', function() vim.api.nvim_command('FloatermToggle') end, mode = 't'},

      { '<leader>v', function() vim.api.nvim_command('FloatermNew --autoclose=2 lazygit') end, mode = 'n'},
      { '<leader>f', function() vim.api.nvim_command('FloatermNew --autoclose=2 yazi') end, mode = 'n'},
    },
    config = function()
      vim.g.floaterm_width = 150
      vim.g.floaterm_height = 40
      vim.g.floaterm_title = false
      vim.g.floaterm_opener = 'edit'
    end
  }
}
