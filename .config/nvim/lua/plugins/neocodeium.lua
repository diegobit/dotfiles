-- neocodeium

return {
  'monkoose/neocodeium',
  event = 'VeryLazy',
  config = function()
    local neocodeium = require 'neocodeium'
    neocodeium.setup {
      debounce = true,
      show_label = true,
      silent = true,
    }
    vim.keymap.set('i', '<A-y>', neocodeium.accept)
    vim.keymap.set('i', '<A-w>', neocodeium.accept_word)
    vim.keymap.set('i', '<A-l>', neocodeium.accept_line)
    vim.keymap.set('i', '<A-n>', neocodeium.cycle)
    vim.keymap.set('i', '<A-c>', neocodeium.clear)

    vim.keymap.set('n', '<leader>tc', '<Cmd>NeoCodeium disable<CR>', { desc = 'neo[C]odeium' })
  end,
}
