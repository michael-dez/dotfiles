-- telescope.nvim
--
-- The extensions are wrapped in pcall so a half-built fzf-native (its `make`
-- step needs a compiler) degrades to plain telescope instead of erroring.
local telescope = require("telescope")

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "dap")
