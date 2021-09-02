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

" Plugs

call plug#begin('~/.vim/plugged')

" Initialize plugin system

  Plug 'preservim/nerdtree'

  Plug 'jremmen/vim-ripgrep'

  Plug 'tpope/vim-fugitive'

  Plug 'vim-utils/vim-man'

  Plug 'mbbill/undotree'

  Plug 'git@github.com:kien/ctrlp.vim.git'

  Plug 'git@github.com:Valloric/YouCompleteMe.git'

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
set nowrap

"-----------------------------------------------------------Misc----------------------------------------------------------------------------------
set incsearch
set undodir=~/.vim/undodir
set undofile

"-----------------------------------------------------------Language Specific----------------------------------------------------------------------------------
syntax on
" YAML
au! BufNewFile,BufReadPost *.{yaml,yml} set filetype=yaml foldmethod=indent
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
