return {
  'rbong/vim-flog',
  -- version = '*',
  branch = 'v3',
  lazy = true,
  cmd = { 'Flog', 'Flogsplit', 'Floggit' },
  dependencies = {
    'tpope/vim-fugitive',
  },
  keys = {
    vim.keymap.set('n', '<leader>tg', '<CMD>Flog<CR>', { desc = '[T]oggle Git [G]raph (Flog)' }),
  },
}
