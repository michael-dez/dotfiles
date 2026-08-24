return {
  { "mfussenegger/nvim-dap" },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    config = function() require("pluginconfig.dapui") end,
  },

  {
    "leoluz/nvim-dap-go",
    ft = { "go" },
    config = function() require("pluginconfig.dap-go") end,
  },
}
