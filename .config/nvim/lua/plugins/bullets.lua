local text_ft = { 'text', 'markdown' }

return {
  'bullets-vim/bullets.vim',
  ft = text_ft,
  event = 'BufReadPre',
  version = '*',
  keys = {
    { '<CR>', '<Plug>(bullets-newline)', mode = 'i', ft = text_ft },
    { '<C-CR>', '<Plug>(bullets-newline)', mode = 'i', ft = text_ft },
    { 'o', '<Plug>(bullets-newline)', mode = 'n', ft = text_ft },
    { 'gR', '<Plug>(bullets-renumber)', mode = { 'n', 'v' }, desc = 'Renumber paragraph', ft = text_ft },
    { 'gx', '<Plug>(bullets-toggle-checkbox)', mode = 'n', desc = 'Toggle checkbox', ft = text_ft },
    { '<C-t>', '<Plug>(bullets-demote)', mode = 'i', desc = 'Demote bullet', ft = text_ft },
    -- TODO: commented, as cmp breaks this
    -- { '<C-d>', '<Plug>(bullets-promote)', mode = 'i', desc = 'Promote bullet', ft = text_ft },
    { '>>', '<Plug>(bullets-demote)', mode = 'n', desc = 'Demote bullet', ft = text_ft },
    { '<<', '<Plug>(bullets-promote)', mode = 'n', desc = 'Promote bullet', ft = text_ft },
    { '>', '<Plug>(bullets-demote)', mode = 'v', desc = 'Demote bullet', ft = text_ft },
    { '<', '<Plug>(bullets-promote)', mode = 'v', desc = 'Promote bullet', ft = text_ft }
  },
  init = function()
    vim.g.bullets_set_mappings = 0
    -- default: ['ROM', 'ABC', 'num', 'abc', 'rom', 'std-', 'std*', 'std+']
    vim.g.bullets_outline_levels = {'ROM', 'ABC', 'num', 'abc', 'rom', 'std-'}
  end,
}
