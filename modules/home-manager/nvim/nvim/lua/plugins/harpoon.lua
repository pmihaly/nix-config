return {
  {
    'ThePrimeagen/harpoon',
    event = 'VeryLazy',
    branch = 'harpoon2',
    dependencies = {
      'nvim-lua/plenary.nvim'
    },
    init = function()
      local harpoon = require('harpoon')

      harpoon:setup()

      vim.keymap.set('n', '<leader>n', function() harpoon:list():append() end)
      vim.keymap.set('n', '<leader>i', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end)

      vim.keymap.set('n', '<leader>h', function() harpoon:list():select(1) end)
      vim.keymap.set('n', '<leader>j', function() harpoon:list():select(2) end)
      vim.keymap.set('n', '<leader>k', function() harpoon:list():select(3) end)
      vim.keymap.set('n', '<leader>l', function() harpoon:list():select(4) end)
    end
  }
}
