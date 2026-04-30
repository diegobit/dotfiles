local text_ft = { 'text', 'markdown' }

local function cursor_is_between_fences()
  local line = vim.api.nvim_get_current_line()
  local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
  local before_cursor = line:sub(1, cursor_col)
  local after_cursor = line:sub(cursor_col + 1)

  return before_cursor:match('^%s*```.*$') ~= nil and after_cursor:match('^```%s*$') ~= nil
end

local function markdown_newline()
  if cursor_is_between_fences() then
    return require('nvim-autopairs').autopairs_cr()
  end

  local bullets_newline = vim.fn.maparg('<Plug>(bullets-newline)', 'i')
  return vim.api.nvim_replace_termcodes(bullets_newline, true, false, true)
end

return {
  'bullets-vim/bullets.vim',
  ft = text_ft,
  event = 'BufReadPre',
  version = '*',
  keys = {
    {
      '<CR>',
      markdown_newline,
      mode = 'i',
      ft = 'markdown',
      expr = true,
      replace_keycodes = false,
      silent = true,
      desc = 'Markdown newline',
    },
    { '<CR>', '<Plug>(bullets-newline)', mode = 'i', ft = 'text' },
    { '<C-CR>', '<Plug>(bullets-newline)', mode = 'i', ft = text_ft },
    { 'o', '<Plug>(bullets-newline)', mode = 'n', ft = text_ft },
    { 'g=', '<Plug>(bullets-renumber)', mode = { 'n', 'v' }, desc = 'Renumber paragraph', ft = text_ft },
    -- { 'gx', '<Plug>(bullets-toggle-checkbox)', mode = 'n', desc = 'Toggle checkbox', ft = text_ft },
    -- similar to how nvim-obsidian does
    { '<CR>', '<Plug>(bullets-toggle-checkbox)', mode = 'n', desc = 'Toggle checkbox', ft = text_ft },
    { '<C-t>', '<Plug>(bullets-demote)', mode = 'i', desc = 'Demote bullet', ft = text_ft },
    -- TODO: commented, as cmp breaks this
    -- { '<C-d>', '<Plug>(bullets-promote)', mode = 'i', desc = 'Promote bullet', ft = text_ft },
    { '>>', '<Plug>(bullets-demote)', mode = 'n', desc = 'Demote bullet', ft = text_ft },
    { '<<', '<Plug>(bullets-promote)', mode = 'n', desc = 'Promote bullet', ft = text_ft },
    { '>', '<Plug>(bullets-demote)', mode = 'v', desc = 'Demote bullet', ft = text_ft },
    { '<', '<Plug>(bullets-promote)', mode = 'v', desc = 'Promote bullet', ft = text_ft },
  },
  init = function()
    vim.g.bullets_set_mappings = 0
    -- default: ['ROM', 'ABC', 'num', 'abc', 'rom', 'std-', 'std*', 'std+']
    vim.g.bullets_outline_levels = { 'ROM', 'ABC', 'num', 'abc', 'rom', 'std-' }
  end,
}
