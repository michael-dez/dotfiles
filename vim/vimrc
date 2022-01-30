" 
"           /\    \                  /\    \                  /\    \                  /\    \                  /\    \         
"          /::\____\                /::\    \                /::\____\                /::\    \                /::\    \        
"         /:::/    /                \:::\    \              /::::|   |               /::::\    \              /::::\    \       
"        /:::/    /                  \:::\    \            /:::::|   |              /::::::\    \            /::::::\    \      
"       /:::/    /                    \:::\    \          /::::::|   |             /:::/\:::\    \          /:::/\:::\    \     
"      /:::/____/                      \:::\    \        /:::/|::|   |            /:::/__\:::\    \        /:::/  \:::\    \    
"      |::|    |                       /::::\    \      /:::/ |::|   |           /::::\   \:::\    \      /:::/    \:::\    \   
"      |::|    |     _____    ____    /::::::\    \    /:::/  |::|___|______    /::::::\   \:::\    \    /:::/    / \:::\    \  
"      |::|    |    /\    \  /\   \  /:::/\:::\    \  /:::/   |::::::::\    \  /:::/\:::\   \:::\____\  /:::/    /   \:::\    \ 
"      |::|    |   /::\____\/::\   \/:::/  \:::\____\/:::/    |:::::::::\____\/:::/  \:::\   \:::|    |/:::/____/     \:::\____\
"      |::|    |  /:::/    /\:::\  /:::/    \::/    /\::/    / ~~~~~/:::/    /\::/   |::::\  /:::|____|\:::\    \      \::/    /
"      |::|    | /:::/    /  \:::\/:::/    / \/____/  \/____/      /:::/    /  \/____|:::::\/:::/    /  \:::\    \      \/____/ 
"      |::|____|/:::/    /    \::::::/    /                       /:::/    /         |:::::::::/    /    \:::\    \             
"      |:::::::::::/    /      \::::/____/                       /:::/    /          |::|\::::/    /      \:::\    \            
"      \::::::::::/____/        \:::\    \                      /:::/    /           |::| \::/____/        \:::\    \           
"       ~~~~~~~~~~               \:::\    \                    /:::/    /            |::|  ~|               \:::\    \          
"                                 \:::\    \                  /:::/    /             |::|   |                \:::\    \         
"                                  \:::\____\                /:::/    /              \::|   |                 \:::\____\        
"                                   \::/    /                \::/    /                \:|   |                  \::/    /        
"                                    \/____/                  \/____/                  \|___|                   \/____/         
"                                                                                                                               
"Me:  Mike Mendez 

"-----------------------------------------------------------PlugIns-------------------------------------------------------------
" auto install vim-plug if not present

let data_dir = has('nvim') ? stdpath('data') . '/site' : '~/.vim'
if empty(glob(data_dir . '/autoload/plug.vim'))
  silent execute '!curl -fLo '.data_dir.'/autoload/plug.vim --create-dirs  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

" set vimspector mappings to F5 (start/continue) F3 (stop) F4 (restart) F6
" (pause) F9 (breakpoint) F10 (step over) F11 (step into) F12 (step out)

let g:vimspector_enable_mappings = 'HUMAN'

" Plugs
call plug#begin('~/.vim/plugged')

" Initialize plugin system

  Plug 'preservim/nerdtree'

  Plug 'tpope/vim-fugitive'

  Plug 'vim-utils/vim-man'

  Plug 'mbbill/undotree'

  Plug 'git@github.com:kien/ctrlp.vim.git'

  Plug 'git@github.com:Valloric/YouCompleteMe.git'

  Plug 'vim-airline/vim-airline'

  Plug 'puremourning/vimspector'

call plug#end()


" Start NERDTree and leave the cursor in it.
"autocmd VimEnter * NERDTree


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
au! BufNewFile,BufReadPost *.json set filetype=json
autocmd FileType json autocmd BufWritePre <buffer> %!python3 -m json.tool 2>/dev/null || echo <buffer>

" Markdown
au! BufNewFile,BufReadPost *.{md,MARKDOWN} set filetype=markdown
autocmd FileType markdown setlocal textwidth=0

"-----------------------------------------------------------Misc----------------------------------------------------------------------------------
set incsearch
set undodir=~/.vim/undodir
set undofile
set noswapfile
set background=dark

let g:ctrlp_show_hidden = 1
"-----------------------------------------------------------Remaps----------------------------------------------------------------------------------
