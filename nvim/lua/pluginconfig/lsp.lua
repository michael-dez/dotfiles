-- nvim-lspconfig
--
-- `capabilities` tells a language server what this editor can do. nvim-cmp
-- advertises extra completion features, so fold those in when it is available.
local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = vim.lsp.protocol.make_client_capabilities()
if ok_cmp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

-- Per-server setup. Disabled; enable a line once mason has installed it.
-- local lspconfig = require("lspconfig")
-- lspconfig.pyright.setup({ capabilities = capabilities })
-- lspconfig.gopls.setup({ capabilities = capabilities })
-- lspconfig.terraformls.setup({ capabilities = capabilities })
-- lspconfig.lua_ls.setup({ capabilities = capabilities })

-- Go: organize imports on save.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("dotfiles_lsp_go", { clear = true }),
  pattern = "*.go",
  callback = function()
    pcall(vim.lsp.buf.code_action, { context = { only = { "source.organizeImports" } }, apply = true })
  end,
})
