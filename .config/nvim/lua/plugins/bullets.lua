
return {
  'bullets-vim/bullets.vim',
  event = 'VeryLazy',
  config = function()
    vim.g.bullets_set_mappings = 0

    vim.keymap.set('i', '<CR>', '<Plug>(bullets-newline)')
    vim.keymap.set('i', '<C-CR>', '<CR>')

    vim.keymap.set('n', 'o', '<Plug>(bullets-newline)')

    vim.keymap.set({ 'n', 'v' }, 'gN', '<Plug>(bullets-renumber)', { desc = 'Renumber' })

    vim.keymap.set('n', 'gx', '<Plug>(bullets-toggle-checkbox)', { desc = 'Toggle checkbox' })

    vim.keymap.set('i', '<C-t>', '<Plug>(bullets-demote)')
    vim.keymap.set('n', '>>', '<Plug>(bullets-demote)', { desc = 'Demote bullet' })
    vim.keymap.set('v', '>', '<Plug>(bullets-demote)')
    vim.keymap.set('i', '<C-d>', '<Plug>(bullets-promote)')
    vim.keymap.set('n', '<<', '<Plug>(bullets-promote)', { desc = 'Promote bullet' })
    vim.keymap.set('v', '<', '<Plug>(bullets-promote)')
  end,
}

