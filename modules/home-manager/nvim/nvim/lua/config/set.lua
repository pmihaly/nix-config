-- Set highlight on search
vim.o.hlsearch = false
vim.o.hlsearch = false
vim.o.incsearch = true

-- Make line numbers default
vim.wo.number = false
vim.wo.relativenumber = false

-- Enable mouse mode
vim.o.mouse = 'a'

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.swapfile = false
vim.o.backup = false
vim.o.undodir = os.getenv('HOME') .. '/.vim/undodir'
vim.o.undofile = true

-- Case insensitive searching UNLESS /C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Decrease update time
vim.o.updatetime = 50

vim.wo.signcolumn = 'yes'

-- Remove UI bloat
vim.o.showcmd = false
vim.o.cmdheight = 0
vim.o.laststatus = 0

vim.o.splitright = true -- Vertical split to the right

-- Always center the cursor
vim.o.scrolloff = 999

-- Use system clipboard
vim.o.clipboard = 'unnamedplus'

-- Set prettier colors
vim.o.termguicolors = true

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

vim.o.conceallevel = 1
