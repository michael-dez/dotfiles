" __            __    __                 __               
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

  "highlights chars for f/t movement
  Plug 'deris/vim-shot-f' 

" Plug 'jiangmao/autopairs'

" Plug 'vim-utils/vim-man'

  Plug 'mbbill/undotree'

" Plug 'bling/vim-bufferline' " :h bufferline

  Plug 'nvim-telescope/telescope.nvim'

  " telescope dependencies
  Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

  Plug 'nvim-lua/plenary.nvim'


  Plug 'williamboman/nvim-lsp-installer' " install lsps with :LspInstall

  Plug 'neovim/nvim-lspconfig' 

  Plug 'L3MON4D3/LuaSnip' " when I get better at lua

  Plug 'kyazdani42/nvim-web-devicons'

  " colorschemes and fluff
  Plug 'morhetz/gruvbox'

  Plug 'wojciechkepka/vim-github-dark'

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
filetype indent on
filetype on

" YAML
au! BufNewFile,BufReadPost *.{yaml,yml} set filetype=yaml foldmethod=indent
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab

" Python

" JSON
" formats json on save, set 'python3' to system specific python command
au! BufNewFile,BufReadPost *.json set filetype=json
autocmd FileType json autocmd BufWritePre <buffer> %!python3 -m json.tool 2>/dev/null || echo <buffer>

" Markdown
au! BufNewFile,BufReadPost *.{md,MARKDOWN} set filetype=markdown
autocmd FileType markdown setlocal textwidth=0

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



"-----------------------------------------------------------Misc----------------------------------------------------------------------------------
set clipboard=unnamedplus
set incsearch
set undodir=~/.vim/undodir
set undofile
"set background=dark
set background=light
" colorscheme
autocmd vimenter * ++nested colorscheme gruvbox
" airline
"let g:airline_powerline_fonts = 1
 
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
"-----------------------------------------------------------Remaps----------------------------------------------------------------------------------
let mapleader=" " " leader = space
set timeoutlen=200 " set timeout for leader key sequence, default seemed very slow for <leader>t for some reason

nnoremap <leader>u :UndotreeShow<CR> 
nnoremap <leader>x !chmod :silent !chmod +x %<CR> "borrowed this one and leader<CR> from @ThePrimeagen
nnoremap <leader>su :command command SuWrite %!sudo tee %
nnoremap <leader>. :edit $MYVIMRC<CR>
nnoremap <leader><CR> :so ~/.config/nvim/init.vim<CR>
nnoremap <leader>xp :put =system(getline('.'))<CR>
nnoremap <leader>/ :Telescope<CR> 
nnoremap <leader>/h :Telescope find_files search_dir=/home/$USER/ hidden=true no_ignore=true<CR> 
nnoremap <leader>/f :Telescope find_files search_dir=/home/$USER/<CR> 
nnoremap <leader>/b :Telescope buffers<CR>
nnoremap <leader>/m :Telescope marks<CR>

" Window navigation
nnoremap <leader>h :wincmd h<CR> 
nnoremap <leader>j :wincmd j<CR> 
nnoremap <leader>k :wincmd k<CR> 
nnoremap <leader>l :wincmd l<CR> 
nnoremap <leader>p :wincmd p<CR> 
nnoremap <leader>wk :sp<CR> 
nnoremap <leader>wl :vsp<CR> 
nnoremap <leader>t :below new<CR><bar>:resize 10<CR><bar>:term<CR><bar>:startinsert<CR>

" lsp remaps
nnoremap <leader>gd :lua vim.lsp.buf.definition()<CR>
nnoremap <leader>gi :lua vim.lsp.buf.implementation()<CR>
nnoremap <leader>gsh :lua vim.lsp.buf.signature_help()<CR>
nnoremap <leader>gr :lua vim.lsp.buf.references()<CR>
nnoremap <leader>grn :lua vim.lsp.buf.rename()<CR>
nnoremap <leader>gh :lua vim.lsp.buf.hover()<CR>
nnoremap <leader>ga :lua vim.lsp.buf.code_action()<CR>

"-----------------------------------------------------------lua----------------------------------------------------------------------------------
" Treesitter configuration 
lua require'nvim-treesitter.configs'.setup { highlight = { enable = true }, incremental_selection = { enable = true }, textobjects = { enable = true }}
" LSP config go/python
lua require'lspconfig'.pyright.setup{}
lua require'lspconfig'.gopls.setup{}
