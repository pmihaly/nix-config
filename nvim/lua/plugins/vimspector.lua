return {
  {
    'puremourning/vimspector',
    keys = {
      { '<Leader>dd', ':call vimspector#Launch()<CR>', mode = 'n' },
      { '<Leader>dq', ':call vimspector#Reset()<CR>', mode = 'n' },
      { '<Leader>dc', ':call vimspector#Continue()<CR>', mode = 'n' },
      { '<Leader>dt', ':call vimspector#ToggleBreakpoint()<CR>', mode = 'n' },
      { '<Leader>dT', ':call vimspector#ClearBreakpoints()<CR>', mode = 'n' },
      { '<Leader>dk', '<Plug>VimspectorRestart', mode = 'n' },
      { '<Leader>dh', '<Plug>VimspectorStepOut', mode = 'n' },
      { '<Leader>dl', '<Plug>VimspectorStepInto', mode = 'n' },
      { '<Leader>dj', '<Plug>VimspectorStepOver', mode = 'n' },
      { '<Leader>dJ', '<Plug>VimspectorRunToCursor', mode = 'n' },
      { '<Leader>di', '<Plug>VimspectorBalloonEval', mode = 'n' },
      { '<Leader>di', '<Plug>VimspectorBalloonEval', mode = 'x' },
    },
    config = function()
      vim.g.vimspector_base_dir = '/Users/mihaly.papp/.local/share/nvim/lazy/vimspector'
      vim.g.vimspector_install_gadgets = { 'debugpy' }
    end,
  },
}
