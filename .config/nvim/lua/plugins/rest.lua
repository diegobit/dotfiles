return {
  'rest-nvim/rest.nvim',
  event = 'BufRead *.http',
  config = function()
    vim.keymap.set('n', '<leader>ds', '<Cmd>Rest run<CR>', { desc = 'Send REST Request (:Rest run)' })
  end,
}
