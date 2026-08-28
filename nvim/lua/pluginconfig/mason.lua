-- mason.nvim: installer for language servers, formatters, and debug adapters.
--
-- Everything mason installs lands in `:echo stdpath("data")`/mason/bin. That
-- directory is not on your shell's PATH, so mason prepends it to nvim's own
-- copy (vim.env.PATH) at setup() time -- that is what lets nvim-lspconfig find
-- `pyright-langserver` by bare name. It is the default, spelled out here so it
-- is obvious why the servers below resolve at all. Check it with:
--   :echo exepath("pyright-langserver")
require("mason").setup({
  PATH = "prepend",
})

-- mason-lspconfig: the bridge between the two.
--
-- `ensure_installed` installs each server on startup if it is missing, so a
-- fresh clone of these dotfiles bootstraps itself. Server names here are
-- mason's (see :Mason), which are not always the lspconfig name -- pyright
-- happens to match, but e.g. terraform-ls is `terraformls` to lspconfig.
--
-- `automatic_enable` (default, left implicit) calls vim.lsp.enable() for every
-- installed server, including right after a first-run install, so a python
-- buffer attaches without a restart. Settings shared by every server live in
-- pluginconfig/lsp.lua.
require("mason-lspconfig").setup({
  ensure_installed = {
    "pyright", -- python; needs node, which is already on PATH here
  },
})
