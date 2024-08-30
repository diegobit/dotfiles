return {
  'stevearc/oil.nvim',
  opts = {},
  event = 'VimEnter',
  -- Optional dependencies
  -- dependencies = { { 'echasnovski/mini.icons', opts = {} } },
  dependencies = { 'nvim-tree/nvim-web-devicons' }, -- use if prefer nvim-web-devicons
  config = function()
    require('oil').setup {
      columns = { 'icon' },
      keymaps = {
        ['<C-h>'] = false,
        ['<C-l>'] = false,
        ['<C-s>'] = { 'actions.select', opts = { horizontal = true, vertical = false }, desc = 'Open the entry in a horizontal split' },
        ['<C-v>'] = { 'actions.select', opts = { vertical = true }, desc = 'Open the entry in a vertical split' },
        ['<C-r>'] = { 'actions.refresh', desc = 'Refresh the tree' },
      },
      view_options = {
        show_hidden = true,
      },
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
    }
    vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
  end,
}
