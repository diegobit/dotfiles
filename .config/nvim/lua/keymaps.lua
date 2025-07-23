-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })

-- Disable arrow keys in normal mode to learn vim motions
-- vim.keymap.set({ 'n', 'i' }, '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set({ 'n', 'i' }, '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set({ 'n', 'i' }, '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set({ 'n', 'i' }, '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Center view when moving vertically by page or half page
-- The function is for avoiding the flickering due
local function lazy_keys(keys)
  keys = vim.api.nvim_replace_termcodes(keys, true, false, true)
  return function()
    local old = vim.o.lazyredraw
    vim.o.lazyredraw = true
    vim.api.nvim_feedkeys(keys, 'nx', false)
    vim.o.lazyredraw = old
  end
end

-- toggle relativenumber
vim.keymap.set('n', '<leader>tr', function()
  vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = 'Relative line numbers' })

vim.keymap.set({ 'n', 'v' }, '<C-f>', lazy_keys '<C-f>zvzz', { desc = 'Scroll down screen' })
vim.keymap.set({ 'n', 'v' }, '<C-b>', lazy_keys '<C-b>zvzz', { desc = 'Scroll up screen' })
vim.keymap.set({ 'n', 'v' }, '<C-d>', lazy_keys '<C-d>zvzz', { desc = 'Scroll down half screen' })
vim.keymap.set({ 'n', 'v' }, '<C-u>', lazy_keys '<C-u>zvzz', { desc = 'Scroll up half screen' })
-- if going to the next search results scrolls the page, scroll AND center
vim.keymap.set('n', 'n', 'nzvzz')
vim.keymap.set('n', 'N', 'Nzvzz')

---- Keybinds to make split navigation easier.
-- Use CTRL+<hjkl> to switch between windows
vim.keymap.set({ 'n', 't' }, '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set({ 'n', 't' }, '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set({ 'n', 't' }, '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
vim.keymap.set({ 'n', 't' }, '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set({ 'n', 't' }, '<C-tab>', '<C-6>', { desc = 'Switch to last active window' })

---- Move current line / block with Alt-j/k (Use these if macos_option_as_alt is true)
-- vim.keymap.set('n', '<M-j>', ':m .+1<CR>==', { desc = 'Move line down' })
-- vim.keymap.set('n', '<M-k>', ':m .-2<CR>==', { desc = 'Move line up' })
-- vim.keymap.set('v', '<M-j>', ":m '>+1<CR>gv=gv", { desc = 'Move block down' })
-- vim.keymap.set('v', '<M-k>', ":m '<-2<CR>gv=gv", { desc = 'Move block up' })
---- The same, but if macos_option_as_alt is `no` - use the special chars of your keyboard layout
-- vim.keymap.set('n', '∆', ':m .+1<CR>==', { desc = 'Move line down' })
-- vim.keymap.set('n', '˚', ':m .-2<CR>==', { desc = 'Move line up' })
-- vim.keymap.set('v', '∆', ":m '>+1<CR>gv=gv", { desc = 'Move block down' })
-- vim.keymap.set('v', '˚', ":m '<-2<CR>gv=gv", { desc = 'Move block up' })
---- The same, but with arrows. Useful if alt+jk are used by something else, eg. aerospace
-- vim.keymap.set('n', '<M-down>', ':m .+1<CR>==', { desc = 'Move line down' })
-- vim.keymap.set('n', '<M-up>', ':m .-2<CR>==', { desc = 'Move line up' })
-- vim.keymap.set('v', '<M-down>', ":m '>+1<CR>gv=gv", { desc = 'Move block down' })
-- vim.keymap.set('v', '<M-up>', ":m '<-2<CR>gv=gv", { desc = 'Move block up' })

-- Canc / delete_forward
vim.keymap.set('i', '<C-l>', '<Del>', { desc = 'Delete forward' })

-- Quick exit -- NOTE: you can exit with ZQ (:q!) or ZZ (:x)

-- Enable macos copy paste shortcuts, for those sad moments where you are using the mouse
vim.keymap.set({ 'i', 'n', 'v' }, '<D-s>', '<Cmd>up<CR><Esc>', { desc = 'Save file' })
vim.keymap.set({ 'n', 'v' }, '<D-c>', '"+y', { desc = 'Yank to system clipboard' })
vim.keymap.set({ 'n', 'v' }, '<D-x>', '"+d', { desc = 'Delete and write to system clipboard' })
vim.keymap.set({ 'n', 'v' }, '<D-a>', 'ggVG', { desc = 'Select all' })

-- paste without overwriting register, delete without writing
vim.keymap.set('v', '<leader>p', '\"_dP', { desc = 'Paste  to null register ("_dP)' })
-- vim.keymap.set({ 'n', 'v' }, '<leader>d', '\"_d', { desc = 'Delete to null register ("_d)' })

-- QuickFix shortcut
-- vim.keymap.set('n', '<leader>tq', '<CMD>copen<CR>', { desc = 'Quickfix List (:copen)' })
vim.keymap.set('n', '[q', '<CMD>cprev<CR>', { desc = 'Previous quickfix entry (:cp)' })
vim.keymap.set('n', ']q', '<CMD>cnext<CR>', { desc = 'Next quickfix entry (:cn)' })

-- toggle spellcheck
vim.keymap.set('n', '<leader>ts', function()
  vim.opt.spell = not vim.opt.spell:get() -- ignore warning
end, { desc = 'Spellcheck' })

-- vim: ts=2 sts=2 sw=2 et
