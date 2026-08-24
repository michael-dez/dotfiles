-- Filetype and language specific behaviour. Nothing here depends on a plugin;
-- plugin-owned autocmds live next to that plugin's config in lua/pluginconfig/.

local aug = vim.api.nvim_create_augroup("dotfiles_ft", { clear = true })

-- YAML
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = { "*.yaml", "*.yml" },
  callback = function()
    vim.bo.filetype = "yaml"
    vim.wo.foldmethod = "indent"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "yaml",
  callback = function()
    vim.cmd("setlocal ts=2 sts=2 sw=2 indentkeys-=0#")
  end,
})

-- Python
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = aug,
  pattern = "*.py",
  callback = function()
    vim.bo.keywordprg = "pydoc3"
    vim.cmd("setlocal indentkeys-=0#")
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "python",
  callback = function(args)
    -- Run current file with python3 on F9
    vim.keymap.set("n", "<F9>", ":w<CR>:exec '!python3' shellescape(@%, 1)<CR>", { buffer = args.buf, silent = true })
    vim.keymap.set("i", "<F9>", "<Esc>:w<CR>:exec '!python3' shellescape(@%, 1)<CR>", { buffer = args.buf, silent = true })
  end,
})

-- JSON
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = "*.json",
  callback = function()
    vim.bo.filetype = "json"
  end,
})

-- Markdown
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = { "*.md", "*.MARKDOWN" },
  callback = function()
    vim.bo.filetype = "markdown"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "markdown",
  callback = function()
    vim.opt_local.textwidth = 0
  end,
})

-- Makefile
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = "makefile",
  callback = function()
    vim.bo.filetype = "make"
    vim.opt_local.expandtab = false
  end,
})

-- Write a file you forgot to open with sudo.
vim.api.nvim_create_user_command("SuWrite", function()
  vim.cmd("write !sudo tee % > /dev/null")
end, {})
