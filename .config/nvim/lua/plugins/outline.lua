return {
  'hedyhli/outline.nvim',
  version = '*',
  lazy = true,
  cmd = { 'Outline', 'OutlineOpen' },
  keys = {
    { '<leader>to', '<cmd>Outline<CR>', mode = 'n', desc = 'Outline' },
  },
  opts = {
    outline_window = {
      winhl = 'Normal:OutlineDark',
      width = 20,
    },
  },
  config = function(_, opts)
    require('outline').setup(opts)
    -- Darker background, same color as trouble
    vim.api.nvim_set_hl(0, 'OutlineDark', { bg = '#16161e' })
  end,
}
