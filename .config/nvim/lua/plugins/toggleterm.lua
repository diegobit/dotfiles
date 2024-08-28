-- toggleterm

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = true 

  vim.keymap.set('n', '<leader>tt', '<Cmd>ToggleTerm<CR>', { desc = '[T]oggle [T]erminal' }),
}
