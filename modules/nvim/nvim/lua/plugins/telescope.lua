return {
  {
    'nvim-telescope/telescope.nvim',
    branch = '0.1.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = vim.fn.executable 'make' == 1,
      }
    },
    build = function() pcall(require('telescope').load_extension, 'fzf') end,
    keys = {
      { '<leader><space>', '<cmd>Telescope find_files<cr>', mode = 'n'},
      { '<leader>g', '<cmd>Telescope live_grep<cr>', mode = 'n'},
      { '<leader>d', '<cmd>Telescope diagnostics<cr>', mode = 'n'},
    },
    opts = {
      defaults = {
        mappings = {
          i = {
            ['<C-u>'] = false,
            ['<C-d>'] = false,
          },
        },
      },
      pickers = {
        find_files = {
          find_command = {'rg', '--files', '--hidden', '-g', '!.git'},
        }
      },
    }
  },
}
