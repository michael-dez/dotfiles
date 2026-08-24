return {
  -- Colorschemes kept around to switch between
  { "morhetz/gruvbox" },
  { "bluz71/vim-nightfly-guicolors" },
  { "nanotech/jellybeans.vim" },

  -- Active colorscheme. priority 1000 makes it load before everything else so
  -- other plugins pick up its highlight groups.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function() require("pluginconfig.catppuccin") end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function() require("pluginconfig.lualine") end,
  },
}
