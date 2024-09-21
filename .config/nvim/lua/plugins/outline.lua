return {
  'hedyhli/outline.nvim',
  lazy = true,
  cmd = { 'Outline', 'OutlineOpen' },
  keys = { -- Example mapping to toggle outline
    { '<leader>to', '<cmd>Outline<CR>', mode = 'n', desc = '[O]utline' },
  },
  opts = {
    -- Your setup opts here
  },
}
