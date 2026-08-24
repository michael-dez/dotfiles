return {
  {
    "williamboman/mason.nvim",
    config = function() require("pluginconfig.mason") end,
  },

  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim" },
    config = function() require("pluginconfig.lsp") end,
  },
}
