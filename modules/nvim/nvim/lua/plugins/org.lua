return {
  {
    'nvim-orgmode/orgmode',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'hrsh7th/nvim-cmp',
      {
        'akinsho/org-bullets.nvim',
        config = true,
      },
      {
        'dhruvasagar/vim-table-mode',
        keys = {
          { '<leader>tm', '<cmd>TableModeToggle<cr>', mode = 'n'},
        }
      }
    },
    config = function()
      require('orgmode').setup_ts_grammar()

      require('orgmode').setup({
        org_agenda_files = {'~/Sync/org/*'},
        org_default_notes_file = '~/Sync/org/refile.org',
      })

    end
  },
}
