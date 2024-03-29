return {
  {
    'epwalsh/obsidian.nvim',
    version = '*',
    lazy = true,
    ft = 'markdown',
    keys = {
      { '<leader>os', function() vim.api.nvim_command('ObsidianSearch') end, mode = 'n'},
      { '<leader>ol', function() vim.api.nvim_command('ObsidianLink') end, mode = 'v'},
      { '<leader>on', function() vim.api.nvim_command('ObsidianLinkNew') end, mode = 'n'},
      { '<leader>on', function() vim.api.nvim_command('ObsidianLinkNew') end, mode = 'v'},
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'hrsh7th/nvim-cmp',
      'nvim-telescope/telescope.nvim',
      'nvim-treesitter',
    },
    opts = {
      workspaces = {
        {
          name = 'tech-notes',
          path = '~/personaldev/tech-notes',
          overrides = {
            notes_subdir = "notes",
          },
        },
      },
    },
  }
}
