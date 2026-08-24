-- Editing, git, and general tools.
--
-- These entries are INSTALLATION ONLY. A `config`/`init` line here never does
-- more than name the matching file in lua/pluginconfig/ -- that is where the
-- actual settings live.
--
--   init   = runs at startup, BEFORE the plugin loads (vim.g.* settings)
--   config = runs AFTER the plugin loads (require(...).setup{} calls)

return {
  -- Lua helper library other plugins depend on
  { "nvim-lua/plenary.nvim" },

  -- Git
  { "tpope/vim-fugitive" },
  { "sindrets/diffview.nvim" },

  -- tpope editing verbs
  { "tpope/vim-surround" },
  { "tpope/vim-unimpaired" },
  { "tpope/vim-repeat" },

  -- Motions
  { "unblevable/quick-scope" },

  -- Tools
  { "mattboehm/vim-unstack" },
  { "mbbill/undotree" },
  { "sbdchd/neoformat" },
  -- { "github/copilot.vim" },

  {
    "mogelbrod/vim-jsonpath",
    init = function() require("pluginconfig.jsonpath") end,
  },

  {
    "voldikss/vim-floaterm",
    init = function() require("pluginconfig.floaterm") end,
  },
}
