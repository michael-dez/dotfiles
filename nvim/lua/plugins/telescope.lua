return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "nvim-telescope/telescope-dap.nvim" },
    },
    config = function() require("pluginconfig.telescope") end,
  },
}
