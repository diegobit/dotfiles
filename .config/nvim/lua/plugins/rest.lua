return {
  'rest-nvim/rest.nvim',
  event = 'BufRead *.http',
  config = function()
    vim.keymap.set('n', '<leader>cs', '<Cmd>Rest run<CR>', { desc = '[S]end REST Request' })
  end,
}
