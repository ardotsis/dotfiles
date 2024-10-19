set relativenumber
set autoindent
set tabstop=2
set shiftwidth=2
set expandtab
set splitright
set clipboard=unnamed
set hls

" Map 'jj' in insert mode to exit to normal mode
inoremap jj <Esc>

" Toggle highlight search when pressing F3 in normal mode
nnoremap <F3> :set hlsearch!<CR>

" Restore cursor on exit
augroup RestoreCursorShapeOnExit
    autocmd!
    autocmd VimLeave * set guicursor=n:block-blinkon500
augroup END
