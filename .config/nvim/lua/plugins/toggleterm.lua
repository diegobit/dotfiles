-- toggleterm

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = true,
  event = 'VeryLazy',
  keys = {
    vim.keymap.set('n', '<leader>tt', '<Cmd>ToggleTerm<CR>', { desc = '[T]oggle [T]erminal' }),
  },
}
