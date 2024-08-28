-- toggleterm

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = true,
  event = 'VeryLazy',

  vim.keymap.set('n', '<leader>tt', '<Cmd>ToggleTerm<CR>', { desc = '[T]oggle [T]erminal' }),
}
