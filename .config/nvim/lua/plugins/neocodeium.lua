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

    -- WARN: <C-[> cannot be remapped! Remapping it means remapping <Esc> !
    vim.keymap.set('i', '<C-space>y', neocodeium.accept, { desc = 'Accept suggestion (Neocodeium)' })
    vim.keymap.set('i', '<C-space>l', neocodeium.accept_line, { desc = 'Accept line (Neocodeium)' })
    vim.keymap.set('i', '<C-space>w', neocodeium.accept_word, { desc = 'Accept word (Neocodeium)' })
    vim.keymap.set('i', '<C-space>n', neocodeium.cycle, { desc = 'Next suggestion (Neocodeium)' })
    vim.keymap.set('i', '<C-space>p', function()
      neocodeium.cycle(-1)
    end, { desc = 'Previous suggestion (Neocodeium)' })
    -- similar to nvim cmp! show/hide
    vim.keymap.set('i', '<C-space>k', function()
      if neocodeium.visible() then
        neocodeium.clear()
      else
        neocodeium.cycle_or_complete()
      end
    end, { desc = 'Show/hide suggestion (Neocodeium)' })

    vim.keymap.set('n', '<C-space>ta', '<Cmd>NeoCodeium disable<CR>', { desc = '[A]I suggestions (Neocodeium)' })
  end,
}
