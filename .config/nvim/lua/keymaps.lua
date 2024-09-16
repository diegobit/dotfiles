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
vim.keymap.set({ 'n', 'i' }, '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set({ 'n', 'i' }, '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set({ 'n', 'i' }, '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set({ 'n', 'i' }, '<down>', '<cmd>echo "Use j to move!!"<CR>')

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
vim.keymap.set({ 'n', 'v' }, '<C-f>', lazy_keys '<C-f>zvzz', { desc = 'Scroll down screen' })
vim.keymap.set({ 'n', 'v' }, '<C-b>', lazy_keys '<C-b>zvzz', { desc = 'Scroll up screen' })
vim.keymap.set({ 'n', 'v' }, '<C-d>', lazy_keys '<C-d>zvzz', { desc = 'Scroll down half screen' })
vim.keymap.set({ 'n', 'v' }, '<C-u>', lazy_keys '<C-u>zvzz', { desc = 'Scroll up half screen' })
-- if going to the next search results scrolls the page, scroll AND center
vim.keymap.set('n', 'n', 'nzvzz')
vim.keymap.set('n', 'N', 'Nzvzz')

-- Keybinds to make split navigation easier.
-- Use CTRL+<hjkl> to switch between windows
-- vim.keymap.set({ 'n', 't' }, '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
-- vim.keymap.set({ 'n', 't' }, '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
-- vim.keymap.set({ 'n', 't' }, '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
-- vim.keymap.set({ 'n', 't' }, '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })

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
-- canc/delete_forward
vim.keymap.set('i', '<C-l>', "<Del>", { desc = 'Delete forward' })

-- Quick exit -- NOTE: you can exit with ZQ (:q!) or ZZ (:x)
-- vim.keymap.set({ 'i', 'n' }, '<C-q>', '<Cmd>bd<CR>', { desc = 'Quit current buffer' })
-- vim.keymap.set('i', '<C-q>', '<Cmd>q<CR>', { desc = 'Quit nvim' })
-- vim.keymap.set('n', '<C-q>', '<Cmd>q<CR>', { desc = 'Quit nvim' })
-- Quick Save file
-- vim.keymap.set({ 'i', 'n' }, '<C-s>', '<Cmd>w<CR><Esc>', { desc = 'Save file' })

-- Quick open explorer
-- vim.keymap.set({ 'i', 'n' }, '<C-e>', '<Cmd>:Ex<CR><Esc>', { desc = 'Open Netrw file explorer' })

-- Send to clipboard with leader [system cliboard disable]
-- vim.keymap.set('n', '<leader>d', '"*d', { desc = 'Delete to clipboard ("*d)' })
-- vim.keymap.set('v', '<leader>d', '"*d', { desc = 'Delete to clipboard ("*d)' })
vim.keymap.set({ 'n', 'v' }, '<leader>x', '"*x', { desc = 'Delete char to clipboard ("*x)' })
-- vim.keymap.set('n', '<leader>c', '"*c', { desc = 'Change to clipboard ("*x)' })
-- vim.keymap.set('v', '<leader>c', '"*c', { desc = 'Change to clipboard ("*x)' })
vim.keymap.set({ 'n', 'v' }, '<leader>y', '"*y', { desc = 'Yank to clipboard ("*y)' })
vim.keymap.set('n', '<leader>Y', '"*Y', { desc = 'Yank to clipboard ("*y)' })

-- QuickFix shortcut
vim.keymap.set('n', '<leader>tq', '<CMD>copen<CR>', { desc = '[Q]uickfix List, (:copen)' })

-- vim: ts=2 sts=2 sw=2 et
