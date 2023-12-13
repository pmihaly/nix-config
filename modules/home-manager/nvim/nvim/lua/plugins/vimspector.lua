return {
  {
    'puremourning/vimspector',
    keys = {
      { '<Leader>dq', ':call vimspector#Reset()<CR>', mode = 'n' },
      { '<Leader>dc', ':call vimspector#Continue()<CR>', mode = 'n' },
      { '<Leader>dt', ':call vimspector#ToggleBreakpoint()<CR>', mode = 'n' },
      { '<Leader>dT', ':call vimspector#ClearBreakpoints()<CR>', mode = 'n' },
      { '<Leader>dr', '<Plug>VimspectorRestart', mode = 'n' },
      { '<Leader>dh', '<Plug>VimspectorStepOut', mode = 'n' },
      { '<Leader>dl', '<Plug>VimspectorStepInto', mode = 'n' },
      { '<Leader>dj', '<Plug>VimspectorRunToCursor', mode = 'n' },
      { '<Leader>dk', '<Plug>VimspectorBalloonEval', mode = 'n' },
      { '<Leader>dk', '<Plug>VimspectorBalloonEval', mode = 'x' },
    },
    config = function()
      vim.g.vimspector_base_dir = '/Users/mihaly.papp/.local/share/nvim/lazy/vimspector'
      vim.g.vimspector_install_gadgets = { 'debugpy' }
    end,
  },
  {
    'nvim-telescope/telescope-vimspector.nvim',
    dependencies = { 'puremourning/vimspector' },
    build = function() pcall(require('telescope').load_extension, 'vimspector') end,
    keys = {
      { '<leader>dd', '<cmd>Telescope vimspector configurations<cr>', mode = 'n'},
    },
  },
}
