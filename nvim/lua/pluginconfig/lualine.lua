-- lualine.nvim: the statusline.
require("lualine").setup({
  -- Filetype-aware statuslines for these plugins' windows.
  extensions = { "fugitive", "fzf", "quickfix", "lazy" },
})
