local servers = {
  dockerls = {},
  jsonls = {},
  kotlin_language_server = {},
  lua_ls = {},
  marksman = {},
  nil_ls = {},
  sqlls = {},
  yamlls = {},
  pylsp = {},
}

return {
  {
    'neovim/nvim-lspconfig',
    event = "BufReadPre",
    dependencies = {
      { 'williamboman/mason.nvim', config = true },
      { 'folke/lsp-colors.nvim'},
      {
        'williamboman/mason-lspconfig.nvim',
        config = function ()

          local on_attach = function(_, bufnr)

            vim.keymap.set('n', 'gap', vim.diagnostic.goto_prev)
            vim.keymap.set('n', 'gan', vim.diagnostic.goto_next)
            vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
            vim.keymap.set('n', '<leader>r', vim.lsp.buf.rename)
            vim.keymap.set('n', 'gh', vim.lsp.buf.code_action)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition)
            vim.keymap.set('n', 'gr', require('telescope.builtin').lsp_references)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation)
            vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover)
            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration)

            vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
              vim.lsp.buf.format()
            end, { desc = 'Format current buffer with LSP' })
          end

          local capabilities = vim.lsp.protocol.make_client_capabilities()
          capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

          local mason_lspconfig = require 'mason-lspconfig'

          mason_lspconfig.setup {
            ensure_installed = vim.tbl_keys(servers),
            automatic_installation = true,
          }

          mason_lspconfig.setup_handlers {
            function(server_name)
              require('lspconfig')[server_name].setup {
                capabilities = capabilities,
                on_attach = on_attach,
                settings = servers[server_name],
              }
            end,
          }

        end
      },
    },
  },
}
