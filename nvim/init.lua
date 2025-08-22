-- Author: Mike Mendez

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Plugins
require("lazy").setup({
  -- Core utilities
  { "nvim-lua/plenary.nvim" },

  -- Git and editing
  { "tpope/vim-fugitive" },
  { "tpope/vim-surround" },
  { "tpope/vim-unimpaired" },
  { "tpope/vim-repeat" },
  { "unblevable/quick-scope" },

  -- Tools
  { "github/copilot.vim" },
  { "mattboehm/vim-unstack" },
  { "mogelbrod/vim-jsonpath" },
  { "mbbill/undotree" },
  { "sbdchd/neoformat" },
  { "voldikss/vim-floaterm" },
  { "sindrets/diffview.nvim" },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      { "nvim-telescope/telescope-dap.nvim" },
    },
    config = function()
      pcall(function() require("telescope").load_extension("fzf") end)
      pcall(function() require("telescope").load_extension("dap") end)
    end,
  },

  -- Markdown preview
  {
    "iamcco/markdown-preview.nvim",
    build = "cd app && yarn install",
    ft = { "markdown" },
  },

  -- ZK notes
  {
    "mickael-menu/zk-nvim",
    config = function()
      require("zk").setup({ picker = "telescope" })
    end,
  },

  -- Treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    config = function()
      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        incremental_selection = { enable = true },
        -- Kept from original; textobjects config is minimal here
        textobjects = { enable = true },
      })
    end,
  },

  -- Mason
  {
    "williamboman/mason.nvim",
    config = function()
      require("mason").setup()
      -- Auto-install language servers
      local mason_registry = require("mason-registry")
      local servers = { "pyright", "gopls", "terraform-ls", "lua-language-server" }

      for _, server in ipairs(servers) do
        if not mason_registry.is_installed(server) then
          vim.cmd("MasonInstall " .. server)
        end
      end
    end,
  },

  -- LSP
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local ok_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      if ok_cmp then
        capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
      end

      -- Setup language servers
      local lspconfig = require("lspconfig")
      lspconfig.pyright.setup({ capabilities = capabilities })
      lspconfig.gopls.setup({ capabilities = capabilities })
      lspconfig.terraformls.setup({ capabilities = capabilities })
      lspconfig.lua_ls.setup({ capabilities = capabilities })

      -- Go import organization on save
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.go",
        callback = function()
          pcall(vim.lsp.buf.code_action, { context = { only = { "source.organizeImports" } }, apply = true })
        end,
      })
    end,
  },

  -- DAP
  { "mfussenegger/nvim-dap" },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "nvim-neotest/nvim-nio" },
    config = function()
      require("dapui").setup()
    end,
  },
  {
    "leoluz/nvim-dap-go",
    ft = { "go" },
    config = function()
      require("dap-go").setup()
    end,
  },

  -- Completion
  { "L3MON4D3/LuaSnip" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "saadparwaiz1/cmp_luasnip" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-cmdline" },
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    config = function()
      vim.opt.completeopt = { "menu", "menuone", "noselect" }

      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
        }, {
          { name = "buffer" },
        }),
      })

      -- Cmdline completion for '/' uses buffer
      cmp.setup.cmdline("/", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = { { name = "buffer" } },
      })

      -- Cmdline completion for ':' uses path and cmdline
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
      })
    end,
  },

  -- Icons
  --{ "kyazdani42/nvim-web-devicons" },

  -- Colorschemes and UI
  { "morhetz/gruvbox" },
  { "bluz71/vim-nightfly-guicolors" },
  { "nanotech/jellybeans.vim" },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
        require("catppuccin").setup({
            auto_integrations = true,
        })
    end,
  },

  -- Statusline
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require("lualine").setup({
          extensions = { 'fugitive', 'fzf', 'quickfix', 'lazy' },
      })
    end,
  }
})

-- General settings
local os_id_like = os.getenv("ID_LIKE") or ""

-- Leader and basic timings
vim.g.mapleader = " "
vim.opt.timeoutlen = 200

-- Options
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.cursorline = true
vim.opt.autoindent = true
vim.opt.expandtab = true
vim.opt.shiftround = true
vim.opt.shiftwidth = 4
vim.opt.smarttab = true
vim.opt.tabstop = 4
vim.opt.linebreak = true
vim.opt.scrolloff = 10
vim.opt.list = true
vim.opt.diffopt:append("vertical")
vim.opt.clipboard = "unnamedplus"
vim.opt.incsearch = true
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.undofile = true

-- True color support
if vim.fn.has("termguicolors") == 1 then
  vim.opt.termguicolors = true
end

-- Ensure undodir exists
pcall(vim.fn.mkdir, vim.opt.undodir:get(), "p")

-- Floaterm settings
vim.g.floaterm_width = 0.9
vim.g.floaterm_height = 0.8

-- Markdown preview settings
vim.g.mkdp_auto_start = 1
vim.g.mkdp_refresh_slow = 0
vim.g.mkdp_filetypes = { "markdown" }
if os_id_like == "arch" then
    vim.g.mkdp_browser = "/usr/bin/firefox"
elseif os_id_like == "debian" then
    vim.g.mkdp_browser = "google-chrome"
end

-- JSONPath register
vim.g.jsonpath_register = "+"

-- Go highlight (kept from original config; harmless if plugin not present)
vim.g.go_highlight_build_constraints = 1
vim.g.go_highlight_extra_types = 1
vim.g.go_highlight_fields = 1
vim.g.go_highlight_functions = 1
vim.g.go_highlight_methods = 1
vim.g.go_highlight_operators = 1
vim.g.go_highlight_structs = 1
vim.g.go_highlight_types = 1
vim.g.go_auto_sameids = 1

-- set colorscheme
vim.cmd.colorscheme("catppuccin-frappe")

-- Filetype and language specific autocmds
local aug = vim.api.nvim_create_augroup("dotfiles_ft", { clear = true })

-- YAML
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = { "*.yaml", "*.yml" },
  callback = function()
    vim.bo.filetype = "yaml"
    vim.wo.foldmethod = "indent"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "yaml",
  callback = function()
    vim.cmd("setlocal ts=2 sts=2 sw=2 indentkeys-=0#")
  end,
})

-- Python
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  group = aug,
  pattern = "*.py",
  callback = function()
    vim.bo.keywordprg = "pydoc3"
    vim.cmd("setlocal indentkeys-=0#")
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "python",
  callback = function(args)
    -- Run current file with python3 on F9
    vim.keymap.set("n", "<F9>", ":w<CR>:exec '!python3' shellescape(@%, 1)<CR>", { buffer = args.buf, silent = true })
    vim.keymap.set("i", "<F9>", "<Esc>:w<CR>:exec '!python3' shellescape(@%, 1)<CR>", { buffer = args.buf, silent = true })
  end,
})

-- JSON
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = "*.json",
  callback = function()
    vim.bo.filetype = "json"
  end,
})

-- Markdown
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = { "*.md", "*.MARKDOWN" },
  callback = function()
    vim.bo.filetype = "markdown"
  end,
})
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "markdown",
  callback = function(args)
    vim.opt_local.textwidth = 0
    -- Markdown preview toggle
    vim.api.nvim_buf_set_keymap(args.buf, "n", "<leader>mt", "<Plug>MarkdownPreviewToggle", { noremap = false, silent = true })
  end,
})

-- Makefile
vim.api.nvim_create_autocmd({ "BufNewFile", "BufReadPost" }, {
  group = aug,
  pattern = "makefile",
  callback = function()
    vim.bo.filetype = "make"
    vim.opt_local.expandtab = false
  end,
})

-- User command for sudo write (improves original mapping)
vim.api.nvim_create_user_command("SuWrite", function()
  vim.cmd("write !sudo tee % > /dev/null")
end, {})

-- Keymaps
local map = vim.keymap.set
local silent = { silent = true }

-- General
map("n", "<leader>u", ":UndotreeShow<CR>", silent)
map("n", "<leader>x", ":silent !chmod +x %<CR>", silent)
map("n", "<leader>su", ":SuWrite<CR>", silent)
map("n", "<leader>.", ":edit $MYVIMRC<CR>", silent)
map("n", "<leader><CR>", ":source $MYVIMRC<CR>", silent)
map("n", "<leader>xp", ":put =system(getline('.'))<CR>", silent)
map("n", "<leader>do", ":DiffOrig<CR>", silent)
map("n", "<leader>jp", ":JsonPath<CR>", silent)

-- Telescope
map("n", "<leader>/", ":Telescope<CR>", silent)
map("n", "<leader>//", ":Telescope live_grep<CR>", silent)
map("n", "<leader>/.", ":Telescope find_files hidden=true no_ignore=true<CR>", silent)
map("n", "<leader>/f", ":Telescope find_files<CR>", silent)
map("n", "<leader>/o", ":Telescope oldfiles<CR>", silent)
map("n", "<leader><leader>", ":Telescope buffers<CR>", silent)
map("n", "<leader>/m", ":Telescope marks<CR>", silent)

-- ZK
map("v", "<leader>zn", ":'<,'>ZkNewFromTitleSelection<CR>", { silent = true })
map("n", "<leader>z", ":ZkNotes<CR>", silent)

-- Window navigation
map("n", "<C-h>", "<C-w>h", silent)
map("n", "<C-j>", "<C-w>j", silent)
map("n", "<C-k>", "<C-w>k", silent)
map("n", "<C-l>", "<C-w>l", silent)
map("n", "<leader>p", "<C-w>p", silent)
map("n", "<leader>wk", ":sp<CR>", silent)
map("n", "<leader>wl", ":vsp<CR>", silent)

-- Floaterm toggle
map("n", "<C-t>", ":FloatermToggle<CR>", silent)
map("t", "<C-t>", "<C-\\><C-n>:FloatermToggle<CR>", silent)
map("i", "<C-t>", "<C-o>:FloatermToggle<CR>", silent)

-- LSP keymaps
map("n", "<leader>gd", function() vim.lsp.buf.definition() end, silent)
map("n", "<leader>gi", function() vim.lsp.buf.implementation() end, silent)
map("n", "<leader>gh", function() vim.diagnostic.open_float() end, silent)
map("n", "<leader>gsh", function() vim.lsp.buf.signature_help() end, silent)
map("n", "<leader>gr", function() vim.lsp.buf.references() end, silent)
map("n", "<leader>grn", function() vim.lsp.buf.rename() end, silent)
map("n", "<leader>ga", function() vim.lsp.buf.code_action() end, silent)

-- DAP keymaps
map("n", "<F5>", function() require("dap").continue() end, silent)
map("n", "<F6>", function() require("dapui").open() end, silent)
map("n", "<F7>", function() require("dapui").close() end, silent)
map("n", "<F10>", function() require("dap").step_over() end, silent)
map("n", "<F11>", function() require("dap").step_into() end, silent)
map("n", "<F12>", function() require("dap").step_out() end, silent)
map("n", "<leader>b", function() require("dap").toggle_breakpoint() end, silent)
map("n", "<leader>B", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, silent)
map("n", "<leader>dr", function() require("dap").repl.open() end, silent)
