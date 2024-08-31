-- toggleterm

return {
  'akinsho/toggleterm.nvim',
  version = '*',
  config = true,
  lazy = true,
  cmd = { 'ToggleTerm', 'ToggleTermSendCurrentLine', 'ToggleTermSendVisualLines', 'ToggleTermSendVisualSelection', 'ToggleTermSetName', 'ToggleTermToggleAll' },
  keys = {
    vim.keymap.set('n', '<leader>tt', '<Cmd>ToggleTerm<CR>', { desc = '[T]erminal' }),
  },
}
