-- Editor settings. Plugin-independent -- nothing here should mention a plugin.
-- (Leader and timeoutlen are set in init.lua, before any mapping exists.)

vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.shiftround = true
vim.opt.shiftwidth = 4
vim.opt.smarttab = true
vim.opt.tabstop = 4
vim.opt.linebreak = true
vim.opt.scrolloff = 10
vim.opt.list = true
vim.opt.diffopt:append("vertical")
vim.opt.clipboard = "unnamedplus"
vim.opt.incsearch = true
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.undofile = true

-- True color support
if vim.fn.has("termguicolors") == 1 then
  vim.opt.termguicolors = true
end

-- Ensure undodir exists
pcall(vim.fn.mkdir, vim.opt.undodir:get(), "p")

-- Leftovers from the vim-go days. vim-go is not installed, so these do
-- nothing today; kept because they cost nothing and matter again the moment
-- vim-go comes back.
vim.g.go_highlight_build_constraints = 1
vim.g.go_highlight_extra_types = 1
vim.g.go_highlight_fields = 1
vim.g.go_highlight_functions = 1
vim.g.go_highlight_methods = 1
vim.g.go_highlight_operators = 1
vim.g.go_highlight_structs = 1
vim.g.go_highlight_types = 1
vim.g.go_auto_sameids = 1
