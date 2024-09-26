return {
  'hedyhli/outline.nvim',
  version = '*',
  lazy = true,
  cmd = { 'Outline', 'OutlineOpen' },
  keys = {
    { '<leader>to', '<cmd>Outline<CR>', mode = 'n', desc = '[O]utline' },
  },
  opts = {
    outline_window = {
      width = 20,
    },
  },
}
