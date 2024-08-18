-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Reset cursor shape at exit
vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    vim.opt.guicursor = 'a:ver25-blinkon1'
  end,
})

-- vim: ts=2 sts=2 sw=2 et
