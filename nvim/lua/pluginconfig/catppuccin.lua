-- catppuccin: the active colorscheme.
require("catppuccin").setup({
  -- Style every installed plugin that catppuccin knows about.
  auto_integrations = true,
})

vim.cmd.colorscheme("catppuccin-frappe")
