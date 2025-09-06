return {
  'rbong/vim-flog',
  lazy = true,
  cmd = { 'Flog', 'Flogsplit', 'Floggit' },
  dependencies = {
    'tpope/vim-fugitive',
  },
  keys = {
    vim.keymap.set('n', '<leader>tG', '<CMD>Flog<CR>', { desc = 'Git Graph (Flog)' }),
  },
}
