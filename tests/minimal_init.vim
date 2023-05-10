set rtp+=.
" TODO this only works if we are using lazy.nvim.
" Might need to dynamically git clone plenary somewhere
" if it's not found, and then add that to the rtp
set rtp+=~/.local/share/nvim/lazy/plenary.nvim
runtime! plugin/plenary.vim
