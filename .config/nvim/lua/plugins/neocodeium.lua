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
    --       The same for <C-i>, which is tab

    -- NOTE: Full set of bindings with <C-space>KEY
    -- vim.keymap.set('i', '<C-space>y', neocodeium.accept, { desc = 'Accept suggestion (Neocodeium)' })
    -- vim.keymap.set('i', '<C-space>l', neocodeium.accept_line, { desc = 'Accept line (Neocodeium)' })
    -- vim.keymap.set('i', '<C-space>w', neocodeium.accept_word, { desc = 'Accept word (Neocodeium)' })
    -- vim.keymap.set('i', '<C-space>n', neocodeium.cycle, { desc = 'Next suggestion (Neocodeium)' })
    -- vim.keymap.set('i', '<C-space>p', function()
    --   neocodeium.cycle(-1)
    -- end, { desc = 'Previous suggestion (Neocodeium)' })
    -- -- similar to nvim cmp! show/hide
    -- vim.keymap.set('i', '<C-space>k', function()
    --   if neocodeium.visible() then
    --     neocodeium.clear()
    --   else
    --     neocodeium.cycle_or_complete()
    --   end
    -- end, { desc = 'Show/hide suggestion (Neocodeium)' })

    -- NOTE: Reduced set of bindings: quicker, just <C-KEY> bindings that should be empty in insert mode
    vim.keymap.set('i', '<C-space>', neocodeium.accept, { desc = 'Accept suggestion (Neocodeium)' })
    vim.keymap.set('i', '<C-g>', neocodeium.accept_word, { desc = 'Accept suggestion (Neocodeium)' })
    vim.keymap.set('i', '<C-x>', neocodeium.clear, { desc = 'Clear suggestion (Neocodeium)' })
    vim.keymap.set('i', '<C-]>', neocodeium.cycle, { desc = 'Next suggestion (Neocodeium)' })

    vim.keymap.set('n', '<leader>ta', '<Cmd>NeoCodeium toggle<CR>', { desc = 'AI autocomplete (Neocodeium)' })
  end,
}
