vim.keymap.set({ 'n', 'v' }, '<Space>', '<Nop>', { silent = true })

vim.keymap.set('n', 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set('n', 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })


vim.keymap.set('v', '<', '<gv', { noremap = true })
vim.keymap.set('v', '>', '>gv', { noremap = true })

vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

vim.keymap.set("n", "<leader>co", function() vim.api.nvim_command('cope') end)
vim.keymap.set("n", "<leader>cn", function() vim.api.nvim_command('cnext') end)
vim.keymap.set("n", "<leader>cp", function() vim.api.nvim_command('cprev') end)

vim.keymap.set("n", "<leader>p", ":set paste<CR>p<CR>:normal =<CR>:set nopaste<CR>")

vim.keymap.set("n", "<leader>ww", function() vim.api.nvim_command('w') end)
vim.keymap.set("n", "<leader>we", function() vim.api.nvim_command('wq') end)
vim.keymap.set("n", "<leader>q", function() vim.api.nvim_command('q!') end)
vim.keymap.set("n", "<leader>wv", function() vim.api.nvim_command('vs') end)
vim.keymap.set("n", "<leader>wh", "<C-w>h")
vim.keymap.set("n", "<leader>wj", "<C-w>j")
vim.keymap.set("n", "<leader>wk", "<C-w>k")
vim.keymap.set("n", "<leader>wl", "<C-w>l")
vim.keymap.set("n", "<leader>s", ":%s//g<Left><Left>")
vim.keymap.set("x", "p", "P", { noremap = true })
