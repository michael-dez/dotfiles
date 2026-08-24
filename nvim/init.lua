-- Author: Mike Mendez
--
-- Entry point. Keep this file SMALL and BORING -- it is the one file that must
-- never break, because it is what gets you back into the rest of the config.
--
-- Where everything lives:
--   lua/config/       editor settings that do not depend on any plugin
--   lua/plugins/      WHICH plugins to install (lazy.nvim specs, nothing else)
--   lua/pluginconfig/ HOW each plugin is configured (plain lua, no lazy syntax)
--
-- See README.md in this directory.

-- Leader must be set before any mapping is defined.
vim.g.mapleader = " "
vim.opt.timeoutlen = 200

-- Settings that can be re-applied at any time, in load order. config.lazy is
-- deliberately absent: lazy.nvim only reads lua/plugins/ once, at startup.
local RELOADABLE = { "config.options", "config.autocmds", "config.keymaps" }

-- Load a module in isolation. An error is reported and skipped rather than
-- aborting the rest of the config, so a typo costs one feature, not nvim.
local function load(module)
  local ok, err = pcall(require, module)
  if not ok then
    vim.notify(("failed to load %s:\n%s"):format(module, err), vim.log.levels.ERROR)
  end
  return ok
end

-- ---------------------------------------------------------------------------
-- Escape hatch
-- ---------------------------------------------------------------------------
-- Defined here, inline and before anything that can fail, using only built-in
-- Neovim features. Break a module below and nvim still starts, prints the
-- error, and leaves you these to open and fix the damage.
local config_dir = vim.fn.stdpath("config")

vim.api.nvim_create_user_command("ConfigDir", function()
  vim.cmd.edit(config_dir)
end, { desc = "Browse the nvim config directory" })

vim.api.nvim_create_user_command("ConfigReload", function()
  -- Drop cached modules so the next require re-reads them from disk. Plugin
  -- config is re-run too; every setup() in lua/pluginconfig/ is safe to repeat.
  local plugin_modules = {}
  for name, _ in pairs(package.loaded) do
    if name:match("^config%.") then
      package.loaded[name] = nil
    elseif name:match("^pluginconfig%.") then
      package.loaded[name] = nil
      table.insert(plugin_modules, name)
    end
  end

  local failed = 0
  for _, module in ipairs(RELOADABLE) do
    if not load(module) then failed = failed + 1 end
  end
  for _, module in ipairs(plugin_modules) do
    if not load(module) then failed = failed + 1 end
  end

  if failed == 0 then
    -- Note: this re-applies settings, it does not undo them. A keymap or
    -- autocmd you deleted from a file is still live until you restart.
    vim.notify("nvim config reloaded", vim.log.levels.INFO)
  else
    vim.notify(("nvim config reloaded, %d module(s) failed"):format(failed), vim.log.levels.WARN)
  end
end, { desc = "Re-run lua/config and lua/pluginconfig (restart for lua/plugins)" })

vim.keymap.set("n", "<leader>.", "<Cmd>edit " .. config_dir .. "/init.lua<CR>", { silent = true })
vim.keymap.set("n", "<leader>cd", "<Cmd>ConfigDir<CR>", { silent = true })
vim.keymap.set("n", "<leader>cr", "<Cmd>ConfigReload<CR>", { silent = true })
vim.keymap.set("n", "<leader><CR>", "<Cmd>ConfigReload<CR>", { silent = true })

-- ---------------------------------------------------------------------------
-- Startup
-- ---------------------------------------------------------------------------
load("config.options")
load("config.lazy") -- bootstraps lazy.nvim and imports lua/plugins/
load("config.autocmds")
load("config.keymaps")
