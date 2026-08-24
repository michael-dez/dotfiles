-- mason.nvim: installer for language servers, formatters, and debug adapters.
require("mason").setup()

-- Auto-install language servers. Disabled; run :Mason and install by hand.
-- local mason_registry = require("mason-registry")
-- local servers = { "pyright", "gopls", "terraform-ls", "lua-language-server" }
--
-- for _, server in ipairs(servers) do
--   if not mason_registry.is_installed(server) then
--     vim.cmd("MasonInstall " .. server)
--   end
-- end
