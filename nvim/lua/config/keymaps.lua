-- All keymaps, in one place.
--
-- The three config-editing maps (<leader>. <leader>cd <leader>cr) are NOT here
-- on purpose -- they live in init.lua so that a mistake in this file cannot
-- take them away.

local map = vim.keymap.set
local silent = { silent = true }

-- General
map("n", "<leader>u", ":UndotreeShow<CR>", silent)
map("n", "<leader>x", ":silent !chmod +x %<CR>", silent)
map("n", "<leader>su", ":SuWrite<CR>", silent)
map("n", "<leader>xp", ":put =system(getline('.'))<CR>", silent)
map("n", "<leader>do", ":DiffOrig<CR>", silent)
map("n", "<leader>jp", ":JsonPath<CR>", silent)

-- Telescope
map("n", "<leader>/", ":Telescope<CR>", silent)
map("n", "<leader>//", ":Telescope live_grep<CR>", silent)
map("n", "<leader>/.", ":Telescope find_files hidden=true no_ignore=true<CR>", silent)
map("n", "<leader>/f", ":Telescope find_files<CR>", silent)
map("n", "<leader>/o", ":Telescope oldfiles<CR>", silent)
map("n", "<leader><leader>", ":Telescope buffers<CR>", silent)
map("n", "<leader>/m", ":Telescope marks<CR>", silent)

-- ZK
map("v", "<leader>zn", ":'<,'>ZkNewFromTitleSelection<CR>", silent)
map("n", "<leader>z", ":ZkNotes<CR>", silent)
map("n", "<leader>zb", ":ZkBuffers<CR>", silent)

-- Window navigation
map("n", "<C-h>", "<C-w>h", silent)
map("n", "<C-j>", "<C-w>j", silent)
map("n", "<C-k>", "<C-w>k", silent)
map("n", "<C-l>", "<C-w>l", silent)
map("n", "<leader>p", "<C-w>p", silent)
map("n", "<leader>wk", ":sp<CR>", silent)
map("n", "<leader>wl", ":vsp<CR>", silent)

-- Floaterm toggle
map("n", "<C-t>", ":FloatermToggle<CR>", silent)
map("t", "<C-t>", "<C-\\><C-n>:FloatermToggle<CR>", silent)
map("i", "<C-t>", "<C-o>:FloatermToggle<CR>", silent)

-- LSP
map("n", "<leader>gd", function() vim.lsp.buf.definition() end, silent)
map("n", "<leader>gi", function() vim.lsp.buf.implementation() end, silent)
map("n", "<leader>gh", function() vim.diagnostic.open_float() end, silent)
map("n", "<leader>gsh", function() vim.lsp.buf.signature_help() end, silent)
map("n", "<leader>gr", function() vim.lsp.buf.references() end, silent)
map("n", "<leader>grn", function() vim.lsp.buf.rename() end, silent)
map("n", "<leader>ga", function() vim.lsp.buf.code_action() end, silent)

-- DAP
map("n", "<F5>", function() require("dap").continue() end, silent)
map("n", "<F6>", function() require("dapui").open() end, silent)
map("n", "<F7>", function() require("dapui").close() end, silent)
map("n", "<F10>", function() require("dap").step_over() end, silent)
map("n", "<F11>", function() require("dap").step_into() end, silent)
map("n", "<F12>", function() require("dap").step_out() end, silent)
map("n", "<leader>b", function() require("dap").toggle_breakpoint() end, silent)
map("n", "<leader>B", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, silent)
map("n", "<leader>dr", function() require("dap").repl.open() end, silent)
