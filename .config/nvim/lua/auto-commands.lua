-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
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

-- Set native formatter for json file (used by gq, but I actually use conform
-- to format). Necessary to format json response in rest.nvim
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'json',
  callback = function()
    vim.bo.formatprg = 'jq'
  end,
})

-- Integration with kitty. kitty will read this variable to know nvim is in focus
vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    group = vim.api.nvim_create_augroup("KittySetVarVimEnter", { clear = true }),
    callback = function()
        io.stdout:write("\x1b]1337;SetUserVar=in_editor=MQo\007")
    end,
})

vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    group = vim.api.nvim_create_augroup("KittyUnsetVarVimLeave", { clear = true }),
    callback = function()
        io.stdout:write("\x1b]1337;SetUserVar=in_editor\007")
    end,
})

---- example custom lint check for rust
-- vim.api.nvim_create_autocmd('FileType', {
--   pattern = 'rust',
--   callback = function()
--     local ra_flycheck = function()
--       local clients = vim.lsp.get_clients {
--         name = 'rust_analyzer',
--       }
--       for _, client in ipairs(clients) do
--         local params = vim.lsp.util.make_text_document_params()
--         client.notify('rust-analyzer/runFlycheck', params)
--       end
--     end
--     vim.keymap.set({ 'n' }, '<leader>cl', ra_flycheck, { desc = '[C]heck [L]int' })
--   end,
-- })

-- Customize mouse right click menu
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    vim.cmd [[
      aunmenu PopUp.How-to\ disable\ mouse
      aunmenu PopUp.-1-
    ]]
  end,
})

-- vim: ts=2 sts=2 sw=2 et
