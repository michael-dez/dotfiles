# nvim config

## Layout

```
init.lua                entry point -- small on purpose, see below
lua/config/             editor settings, no plugins involved
  options.lua             vim.opt / vim.g settings
  keymaps.lua             every keymap
  autocmds.lua            filetype behaviour, :SuWrite
  lazy.lua                bootstraps lazy.nvim, imports lua/plugins/
lua/plugins/            WHICH plugins to install (lazy.nvim specs)
lua/pluginconfig/       HOW each plugin is configured (plain lua)
```

## The two-file rule for plugins

A file in `lua/plugins/` says only *what to install*: the repo name, its
dependencies, its build step, and when to load it. When a plugin needs real
configuration, the spec's only job is to name a file in `lua/pluginconfig/`:

```lua
-- lua/plugins/ui.lua -- installation
{
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function() require("pluginconfig.lualine") end,
}
```

```lua
-- lua/pluginconfig/lualine.lua -- configuration
require("lualine").setup({
  extensions = { "fugitive", "fzf", "quickfix", "lazy" },
})
```

That keeps settings out of nested lazy.nvim tables. To tweak a plugin, open its
file in `lua/pluginconfig/` and ignore `lua/plugins/` entirely.

`init` vs `config` in a spec:

- `init` runs at startup, **before** the plugin loads. Use it for `vim.g.*`
  settings, which most old vimscript plugins read as they load.
- `config` runs **after** the plugin loads. Use it for `require("x").setup{}`.

## Adding a plugin

1. Add the spec to whichever file in `lua/plugins/` fits (or make a new file --
   `lua/config/lazy.lua` imports the whole directory, so nothing else to edit).
2. If it needs settings, create `lua/pluginconfig/<name>.lua` and point the
   spec's `config` at it.
3. Restart nvim; lazy.nvim installs it.

## Why init.lua is tiny

Everything in `init.lua` runs before anything that can fail, and each module
below is loaded under `pcall` -- a syntax error in one file gets reported and
skipped instead of taking down the whole config.

These maps are defined in `init.lua` itself, using only built-in Neovim
features, so a broken module can never take them away:

| map            | does                                   |
|----------------|----------------------------------------|
| `<leader>.`    | edit `init.lua`                        |
| `<leader>cd`   | browse the config directory            |
| `<leader>cr`   | reload config (`<leader><CR>` too)     |

`:ConfigDir` and `:ConfigReload` are the same thing as commands. Reload covers
`lua/config/` and `lua/pluginconfig/`; changes to `lua/plugins/` still need a
restart, since lazy.nvim reads those specs once at startup.

## Install

`~/.config/nvim/init.lua` and `~/.config/nvim/lua` are symlinks into this repo
(see `install.sh` / `install.yml`). `lazy-lock.json` stays outside the repo.
