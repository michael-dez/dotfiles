return {
  {
    "mason-org/mason.nvim",
    dependencies = { "mason-org/mason-lspconfig.nvim" },
    config = function() require("pluginconfig.mason") end,
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "mason-org/mason.nvim" },
    config = function() require("pluginconfig.lsp") end,
  },
}
