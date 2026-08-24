return {
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && yarn install",
    ft = { "markdown" },
    init = function() require("pluginconfig.markdown-preview") end,
  },

  {
    "mickael-menu/zk-nvim",
    config = function() require("pluginconfig.zk") end,
  },
}
