" DO NOT EDIT THIS FILE
" Add your own customizations in ~/.config/vim/my_configs.vim

set runtimepath+=~/.config/vim

source ~/.config/vim/vimrcs/basic.vim
source ~/.config/vim/vimrcs/filetypes.vim
source ~/.config/vim/vimrcs/plugins_config.vim
source ~/.config/vim/vimrcs/extended.vim
try
  source ~/.config/vim/my_configs.vim
catch
endtry
