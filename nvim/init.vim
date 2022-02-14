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

  Plug 'vim-utils/vim-man'

  Plug 'mbbill/undotree'

  Plug 'L3MON4D3/LuaSnip' " when I get better at lua

  Plug 'vim-airline/vim-airline' " :h airline

  Plug 'bling/vim-bufferline' " :h bufferline

  Plug 'kyazdani42/nvim-web-devicons'

  Plug 'neovim/nvim-lspconfig' 

  Plug 'williamboman/nvim-lsp-installer' " install lsps with :LspInstall

  Plug 'nvim-telescope/telescope.nvim'

  " telescope dependencies
  Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

  Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}

  " colorschemes
  Plug 'morhetz/gruvbox'

call plug#end()



"-----------------------------------------------------------Numbers and Indentation-------------------------------------------------------------
set relativenumber
set autoindent
set expandtab
set shiftround
set shiftwidth=4
set smarttab
set tabstop=4
set wrap
set linebreak


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
set incsearch
set undodir=~/.vim/undodir
set undofile
set noswapfile
set background=dark
" colorscheme
autocmd vimenter * ++nested colorscheme gruvbox
"-----------------------------------------------------------Remaps----------------------------------------------------------------------------------
let mapleader = " " " leader = space

nnoremap <leader>u :UndotreeShow<CR> 
nnoremap <leader>x !chmod :silent !chmod +x %<CR> "borrowed this one and leader<CR> from @ThePrimeagen
nnoremap <leader><CR> :so ~/.config/nvim/init.vim<CR>
nnoremap <leader>t :Telescope<CR> 
nnoremap <leader>tf :Telescope find_files hidden=true no_ignore=true<CR> 
nnoremap <leader>th :Telescope find_files search_dir=/home/$USER/<CR> 
" Window navigation
nnoremap <leader>h :wincmd h<CR> 
nnoremap <leader>j :wincmd j<CR> 
nnoremap <leader>k :wincmd k<CR> 
nnoremap <leader>l :wincmd l<CR> 
nnoremap <leader>p :wincmd p<CR> 
nnoremap <leader>nwk :sp<CR> 
nnoremap <leader>nwl :vsp<CR> 

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
" LSP config
lua require'lspconfig'.pyright.setup{}
lua require'lspconfig'.gopls.setup{}
