return {
  -- Snippets and completion sources. No settings of their own -- nvim-cmp
  -- wires them together in lua/pluginconfig/cmp.lua.
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-cmdline" },

  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function() require("pluginconfig.cmp") end,
  },
}
