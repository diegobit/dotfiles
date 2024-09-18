-- Neocodeium: unofficial implementation of codeium (Exafunction/codeium.nvim)

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

    -- Keymaps based on CTRL, to not conflict with alt used to input special chars
    -- WARN: <C-[> cannot be remapped! Remapping it means remapping <Esc> !
    vim.keymap.set('i', '<C-space>y', neocodeium.accept)
    vim.keymap.set('i', '<C-space>l', neocodeium.accept_line)
    vim.keymap.set('i', '<C-space>w', neocodeium.accept_word)
    vim.keymap.set('i', '<C-space>n', neocodeium.cycle)
    vim.keymap.set('i', '<C-space>p', function()
      neocodeium.cycle(-1)
    end)
    vim.keymap.set('i', '<C-space>c', neocodeium.clear)

    -- Keymaps based on Alt, to be intuitive, but just using a different modifier
    -- vim.keymap.set('i', '<A-y>', neocodeium.accept)
    -- vim.keymap.set('i', '<A-w>', neocodeium.accept_word)
    -- vim.keymap.set('i', '<A-l>', neocodeium.accept_line)
    -- vim.keymap.set('i', '<A-n>', neocodeium.cycle)
    -- vim.keymap.set('i', '<A-c>', neocodeium.clear)

    vim.keymap.set('n', '<leader>tc', '<Cmd>NeoCodeium disable<CR>', { desc = 'neo[C]odeium' })
  end,
}
