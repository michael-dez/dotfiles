-- nvim-lspconfig
--
-- On nvim 0.11+ this plugin is just a library of server definitions: one
-- lsp/<name>.lua per server, dropped on the runtimepath. Nothing here starts a
-- server. vim.lsp.enable() does, and mason-lspconfig calls it for every server
-- it has installed (see pluginconfig/mason.lua).

-- `capabilities` tells a language server what this editor can do. nvim-cmp
-- advertises extra completion features, so fold those in when it is available.
local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local capabilities = vim.lsp.protocol.make_client_capabilities()
if ok_cmp then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

-- "*" is the fallback config every server merges on top of, so this applies to
-- servers added later without another edit here.
vim.lsp.config("*", {
  capabilities = capabilities,
})

-- Per-server overrides. Each one is merged over the "*" block above and over
-- the defaults nvim-lspconfig ships, so only state what differs.
vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        -- "off" | "basic" | "standard" | "strict"
        typeCheckingMode = "standard",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        diagnosticMode = "openFilesOnly",
      },
    },
  },
})

-- Go: organize imports on save.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("dotfiles_lsp_go", { clear = true }),
  pattern = "*.go",
  callback = function()
    pcall(vim.lsp.buf.code_action, { context = { only = { "source.organizeImports" } }, apply = true })
  end,
})
