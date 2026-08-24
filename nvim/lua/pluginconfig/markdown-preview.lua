-- markdown-preview.nvim
--
-- These are vim.g settings, so they must be applied before the plugin loads --
-- which is why the spec calls this from `init` rather than `config`.
vim.g.mkdp_auto_start = 1
vim.g.mkdp_refresh_slow = 0
vim.g.mkdp_filetypes = { "markdown" }

-- Which browser to open the preview in. The old test here was on
-- os.getenv("ID_LIKE"), which was always nil: zshrc/zshenv source
-- /etc/os-release but export only DISTRO, so ID_LIKE never reached the
-- environment and the Chrome-on-Windows branch was unreachable on every host.
local is_wsl = (os.getenv("WSL_DISTRO_NAME") ~= nil)

if is_wsl then
  vim.g.mkdp_browser = "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
elseif vim.fn.executable("firefox") == 1 then
  vim.g.mkdp_browser = vim.fn.exepath("firefox")
else
  vim.g.mkdp_browser = ""
end

-- Toggle the preview from any markdown buffer.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("dotfiles_mkdp", { clear = true }),
  pattern = "markdown",
  callback = function(args)
    vim.keymap.set("n", "<leader>mt", "<Plug>MarkdownPreviewToggle", { buffer = args.buf, silent = true })
  end,
})
