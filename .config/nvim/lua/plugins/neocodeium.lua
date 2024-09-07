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
    vim.keymap.set('i', '<C-enter>', neocodeium.accept)
    -- vim.keymap.set('i', '<C-W>', neocodeium.accept_word)
    vim.keymap.set('i', '<C-l>', neocodeium.accept_line)
    vim.keymap.set('i', '<C-]>', function()
      neocodeium.cycle(1)
    end)
    vim.keymap.set('i', '<C-[>', function()
      neocodeium.cycle(-1)
    end)
    vim.keymap.set('i', '<C-q>', neocodeium.clear)

    vim.keymap.set('n', '<leader>tc', '<Cmd>NeoCodeium disable<CR>', { desc = 'neo[C]odeium' })
  end,
}
