return {
  {
    'nvim-neotest/neotest',
    keys = {
      { '<leader>tr', function() require('neotest').run.run() end, mode = 'n'},
      { '<leader>ta', function() require('neotest').run.run(vim.fn.expand('%')) end, mode = 'n'},
      { '<leader>tl', function() require('neotest').run.run_last() end, mode = 'n'},
      { '<leader>ts', function() require('neotest').summary.toggle() end, mode = 'n'},
      { '<leader>to', function() require('neotest').output_panel.toggle() end, mode = 'n'},
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-treesitter/nvim-treesitter',
      'antoinemadec/FixCursorHold.nvim',
      {
        'nvim-neotest/neotest-python',
        dependencies = {
          'nvim-treesitter/nvim-treesitter',
        }
      },
    },
    opts = function()
      return {
        adapters = {
          require('neotest-python')({
            dap = { justMyCode = false },
          })
        }
      }
    end,
  },
}

