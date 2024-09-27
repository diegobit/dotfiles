-- zen-mode

return {
  'folke/zen-mode.nvim',
  lazy = true,
  cmd = { 'ZenMode' },
  opts = {
    window = {
      width = 150,
      backdrop = 0.85,
    },
    plugins = {
      options = {
        -- laststatus = 3,
        cmdheight = 0
      },
    },
  },

  keys = {
    vim.keymap.set('n', '<leader>tz', ':ZenMode<CR>', { desc = 'Zenmode' }),
  },
}
