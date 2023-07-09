"color __            __    __                 __               
"|  \          |  \  |  \               |  \              
" \$$ _______   \$$ _| $$_    __     __  \$$ ______ ____  
"|  \|       \ |  \|   $$ \  |  \   /  \|  \|      \    \ 
"| $$| $$$$$$$\| $$ \$$$$$$   \$$\ /  $$| $$| $$$$$$\$$$$\
"| $$| $$  | $$| $$  | $$ __   \$$\  $$ | $$| $$ | $$ | $$
"| $$| $$  | $$| $$  | $$|  \ __\$$ $$  | $$| $$ | $$ | $$
"| $$| $$  | $$| $$   \$$  $$|  \\$$$   | $$| $$ | $$ | $$
" \$$ \$$   \$$ \$$    \$$$$  \$$ \$     \$$ \$$  \$$  \$$
"                                                         
"                                                         
"                                                          
"Me:  Mike Mendez 
"
"-----------------------------------------------------------PlugIns-------------------------------------------------------------
" auto install vim-plug if not present

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" Plugs
call plug#begin('~/.vim/plugged')

" Initialize plugin system

  Plug 'tpope/vim-fugitive'

  Plug 'tpope/vim-surround'

  Plug 'tpope/vim-unimpaired' " I only use [q & ]q

  Plug 'unblevable/quick-scope'   "highlights chars for f/t movement

" Plug 'jiangmao/autopairs'

" Plug 'vim-utils/vim-man'

  Plug 'mattboehm/vim-unstack'

  Plug 'mogelbrod/vim-jsonpath'

  Plug 'mbbill/undotree'

" Plug 'bling/vim-bufferline' " :h bufferline

  Plug 'nvim-telescope/telescope.nvim' " the best picker because tj

  Plug 'voldikss/vim-floaterm' " floating terminal

  "Plug 'TimUntersberger/neogit' " git tui

  Plug 'sbdchd/neoformat' " formatter

  Plug 'iamcco/markdown-preview.nvim', { 'do': 'cd app && yarn install' } " should auto-open markdown previews

  Plug 'mickael-menu/zk-nvim'

  Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }   " telescope dependency

  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

  Plug 'nvim-lua/plenary.nvim'

  Plug 'sindrets/diffview.nvim' 

  Plug 'williamboman/mason.nvim' " vim package manager

  Plug 'williamboman/mason-lspconfig.nvim'

  Plug 'neovim/nvim-lspconfig' 

  " completion and prereqs
  Plug 'L3MON4D3/LuaSnip' " when I get better at lua

  Plug 'hrsh7th/nvim-cmp'

  Plug 'hrsh7th/cmp-nvim-lsp'

  Plug 'saadparwaiz1/cmp_luasnip'

  Plug 'kyazdani42/nvim-web-devicons'   " devicons

  " colorschemes and fluff
  Plug 'morhetz/gruvbox'

  Plug 'wojciechkepka/vim-github-dark'

  Plug 'bluz71/vim-nightfly-guicolors'
  
  Plug 'catppuccin/vim', { 'as': 'catppuccin' }

  Plug 'nanotech/jellybeans.vim'

  Plug 'vim-airline/vim-airline' " :h airline

  Plug 'vim-airline/vim-airline-themes' ":AirlineTheme
call plug#end()



"-----------------------------------------------------------Formatting-------------------------------------------------------------
set relativenumber number
set cursorline
set autoindent
set expandtab
set shiftround
set shiftwidth=4
set smarttab
set tabstop=4
set linebreak
set scrolloff=10
set list


"-----------------------------------------------------------Language Specific----------------------------------------------------------------------------------
syntax on
filetype plugin on
filetype indent on
filetype on

" YAML
au! BufNewFile,BufReadPost *.{yaml,yml} set filetype=yaml foldmethod=indent
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

" Python
autocmd FileType python map <buffer> <F9> :w<CR>:exec '!python3' shellescape(@%, 1)<CR>
autocmd FileType python imap <buffer> <F9> <esc>:w<CR>:exec '!python3' shellescape(@%, 1)<CR>
autocmd BufNewFile,BufRead *.py set keywordprg=pydoc3
" JSON
" formats json on save, set 'python3' to system specific python command
au! BufNewFile,BufReadPost *.json set filetype=json
"autocmd FileType json autocmd BufWritePre <buffer> %!python3 -m json.tool 2>/dev/null || echo <buffer>
let g:jsonpath_register = '+'

" Markdown
au! BufNewFile,BufReadPost *.{md,MARKDOWN} set filetype=markdown
autocmd FileType markdown setlocal textwidth=0
let g:mkdp_auto_start = 1 " autostart markdown preview in new markdown buffer
let g:mkdp_refresh_slow = 0 " refresh when exiting insert or on write
let g:mkdp_filetypes = ['markdown'] " filetypes associated with markdown preview
    let g:mkdp_browser = '/usr/bin/firefox'

" Go
" highlighting
let g:go_highlight_build_constraints = 1
let g:go_highlight_extra_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_operators = 1
let g:go_highlight_structs = 1
let g:go_highlight_types = 1
let g:go_auto_sameids = 1

" Makefile
 au! BufNewFile,BufReadPost makefile set filetype=make noexpandtab


"-----------------------------------------------------------Misc----------------------------------------------------------------------------------
set clipboard=unnamedplus
set incsearch
set undodir=~/.vim/undodir
set undofile
" floaterm settings
let g:floaterm_width = 0.9
let g:floaterm_height = 0.8

" colorscheme
autocmd vimenter * ++nested colorscheme catppuccin_frappe
"set background=NONE
"set background=light

" WSL yank support
let s:clip = '/mnt/c/Windows/System32/clip.exe'  " change this path according to your mount point
if executable(s:clip)
    augroup WSLYank
        autocmd!
        autocmd TextYankPost * if v:event.operator ==# 'y' | call system(s:clip, @0) | endif
    augroup END
endif

 " true color support
"Use 24-bit (true-color) mode in Vim/Neovim when outside tmux.
"If you're using tmux version 2.2 or later, you can remove the outermost $TMUX check and use tmux's 24-bit color support
"(see < http://sunaku.github.io/tmux-24bit-color.html#usage > for more information.)
if (empty($TMUX))
  if (has("nvim"))
    "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
    let $NVIM_TUI_ENABLE_TRUE_COLOR=1
  endif
  "For Neovim > 0.1.5 and Vim > patch 7.4.1799 < https://github.com/vim/vim/commit/61be73bb0f965a895bfb064ea3e55476ac175162 >
  "Based on Vim patch 7.4.1770 (`guicolors` option) < https://github.com/vim/vim/commit/8a633e3427b47286869aa4b96f2bfc1fe65b25cd >
  " < https://github.com/neovim/neovim/wiki/Following-HEAD#20160511 >
  if (has("termguicolors"))
    set termguicolors
  endif
endif

"Set bg transparency
"hi Normal guibg=NONE ctermbg=NONE

"-----------------------------------------------------------Remaps----------------------------------------------------------------------------------
let mapleader=" " " leader = space
set timeoutlen=200 " set timeout for leader key sequence, default seemed very slow for <leader>t for some reason

nnoremap <leader>u :UndotreeShow<CR> 
nnoremap <leader>x !chmod :silent !chmod +x %<CR> " borrowed this one and leader<CR> from @ThePrimeagen
nnoremap <leader>su :command command SuWrite %!sudo tee %
nnoremap <leader>. :edit $MYVIMRC<CR>
nnoremap <leader><CR> :so $MYVIMRC<CR>
nnoremap <leader>xp :put =system(getline('.'))<CR>
nnoremap <leader>do :DiffOrig<CR> " TODO. https://neovim.io/doc/user/diff.html#:DiffOrig
nnoremap <leader>jp :JsonPath<CR>
nnoremap <leader>/ :Telescope<CR> 
nnoremap <leader>// :Telescope live_grep<CR> 
nnoremap <leader>/. :Telescope find_files hidden=true no_ignore=true<CR> 
nnoremap <leader>/f :Telescope find_files<CR> 
nnoremap <leader>/o :Telescope old_files<CR> 
nnoremap <leader><leader> :Telescope buffers<CR>
nnoremap <leader>/m :Telescope marks<CR>

" markdown preview
autocmd FileType markdown nnoremap <leader>mt <Plug>MarkdownPreviewToggle

" zk
nnoremap <leader>zn :'<,'>ZkNewFromTitleSelection<CR>
nnoremap <leader>z/ :ZkNotes<CR>

" Window navigation
nnoremap <C-h> :wincmd h<CR>
nnoremap <C-j> :wincmd j<CR>
nnoremap <C-k> :wincmd k<CR>
nnoremap <C-l> :wincmd l<CR>
nnoremap <leader>p :wincmd p<CR>
nnoremap <leader>wk :sp<CR>
nnoremap <leader>wl :vsp<CR>
"nnoremap <leader>t :below new<CR><bar>:resize 10<CR><bar>:term<CR><bar>:startinsert<CR>
nnoremap <C-t> :FloatermToggle<CR>
tnoremap <C-t> <C-\><C-n>:FloatermToggle<CR>
inoremap <C-t> <C-o>:FloatermToggle<CR>
" git
nnoremap <C-g> :Neogit<CR>
" lsp remaps
nnoremap <leader>gd :lua vim.lsp.buf.definition()<CR>
nnoremap <leader>gi :lua vim.lsp.buf.implementation()<CR>
nnoremap <leader>gh :lua vim.lsp.diagnostic.open_float()<CR>
nnoremap <leader>gsh :lua vim.lsp.buf.signature_help()<CR>
nnoremap <leader>gr :lua vim.lsp.buf.references()<CR>
nnoremap <leader>grn :lua vim.lsp.buf.rename()<CR>
nnoremap <leader>ga :lua vim.lsp.buf.code_action()<CR>

"-----------------------------------------------------------lua----------------------------------------------------------------------------------
" Treesitter configuration 
lua require'nvim-treesitter.configs'.setup { highlight = { enable = true }, incremental_selection = { enable = true }, textobjects = { enable = true }}
" mason setup https://github.com/williamboman/mason.nvim#setup
lua require("mason").setup()
lua require("mason-lspconfig").setup({ensure_installed = { "pyright", "gopls", "bashls", "ansiblels", "dockerls", "terraformls" }})
" zk-vim setup https://github.com/mickael-menu/zk-nvim#setup
lua require("zk").setup()
" LSP config
lua require'lspconfig'.pyright.setup{}
lua require'lspconfig'.gopls.setup{}
lua require'lspconfig'.bashls.setup{}
lua require'lspconfig'.ansiblels.setup{}
lua require'lspconfig'.dockerls.setup{}
lua require'lspconfig'.terraformls.setup{}
" completion options and lua script
set completeopt=menu,menuone,noselect

lua <<EOF
-- Setup nvim-cmp.
  local cmp = require'cmp'

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
      end,
    },
    window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
    },
    mapping = cmp.mapping.preset.insert({
      ['<C-b>'] = cmp.mapping.scroll_docs(-4),
      ['<C-f>'] = cmp.mapping.scroll_docs(4),
      ['<C-Space>'] = cmp.mapping.complete(),
      ['<C-e>'] = cmp.mapping.abort(),
      ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    }),
    sources = cmp.config.sources({
      { name = 'nvim_lsp' },
      { name = 'luasnip' }, -- For luasnip users.
    }, {
      { name = 'buffer' },
    })
  })

  -- Set configuration for specific filetype.
--  cmp.setup.filetype('gitcommit', {
--    sources = cmp.config.sources({
--      { name = 'cmp_git' }, -- You can specify the `cmp_git` source if you were installed it.
--    }, {
--      { name = 'buffer' },
--    })
--  })

  -- Use buffer source for `/` (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline('/', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = {
      { name = 'buffer' }
    }
  })

  -- Use cmdline & path source for ':' (if you enabled `native_menu`, this won't work anymore).
  cmp.setup.cmdline(':', {
    mapping = cmp.mapping.preset.cmdline(),
    sources = cmp.config.sources({
      { name = 'path' }
    }, {
      { name = 'cmdline' }
    })
  })

  -- Setup lspconfig.
  local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())
  -- Replace <YOUR_LSP_SERVER> with each lsp server you've enabled.
  require('lspconfig')['pyright'].setup {
    capabilities = capabilities
  }
  require('lspconfig')['gopls'].setup {
    capabilities = capabilities
  }
EOF
