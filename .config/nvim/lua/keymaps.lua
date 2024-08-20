-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
-- Toggleterm enable
vim.keymap.set('n', '<leader>tt', '<Cmd>ToggleTerm<CR>', { desc = 'Toggle terminal' })

-- Disable arrow keys in normal mode to learn vim motions
vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
-- Use CTRL+<hjkl> to switch between windows
vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })
-- The same, but in terminal mode
vim.keymap.set('t', '<C-h>', '<Cmd>wincmd h<CR>', { desc = 'Move focus to the upper window' })
vim.keymap.set('t', '<C-j>', '<Cmd>wincmd j<CR>', { desc = 'Move focus to the lower window' })
vim.keymap.set('t', '<C-k>', '<Cmd>wincmd k<CR>', { desc = 'Move focus to the upper window' })
vim.keymap.set('t', '<C-l>', '<Cmd>wincmd l<CR>', { desc = 'Move focus to the right window' })

-- Move current line / block with Alt-j/k ala vscode.
vim.keymap.set('n', '<M-j>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<M-k>', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('v', '<M-j>', ":m '>+1<CR>gv=gv", { desc = 'Move block down' })
vim.keymap.set('v', '<M-k>', ":m '<-2<CR>gv=gv", { desc = 'Move block up' })

-- Zenmode
vim.keymap.set('n', '<leader>z', ':ZenMode<CR>', { desc = 'Toggle Zenmode' })

-- Quick exit
vim.keymap.set('i', '<C-q>', '<Cmd>q<CR>', { desc = 'Quit current buffer' })
vim.keymap.set('n', '<C-q>', '<Cmd>q<CR>', { desc = 'Quit current buffer' })
-- Quick Save file
vim.keymap.set('i', '<C-s>', '<cmd>w<CR>', { desc = 'Save file' })
vim.keymap.set('n', '<C-s>', '<cmd>w<CR>', { desc = 'Save file' })

-- clipboard and yanking. What yanks?
-- Rule of thumb: yanks what visual selects; except for d, because there is already x
--
--      char:   d    D    x    X    c    C
--      mode:  v n  v n  v n  v n  v n  v n
--
-- Yank? YES:            x    x    x    x
--        NO:  x x  x x    x    x    x    x
--
vim.keymap.set('n', 'd', '"_d', { desc = 'Delete without yanking' })
vim.keymap.set('v', 'd', '"_d', { desc = 'Delete without yanking' })
vim.keymap.set('n', 'D', '"_D', { desc = 'Delete char without yanking' })
vim.keymap.set('v', 'D', '"_D', { desc = 'Delete char without yanking' })

vim.keymap.set('n', 'x', '"_x', { desc = 'Delete char without yanking' })
vim.keymap.set('n', 'X', '"_x', { desc = 'Delete char without yanking' })

vim.keymap.set('n', 'c', '"_c', { desc = 'Change without yanking' })
vim.keymap.set('n', 'C', '"_C', { desc = 'Change without yanking' })

-- OLD METHOD with leader
-- vim.keymap.set('n', '<leader>d', '"_d', { desc = 'Delete without yanking' })
-- vim.keymap.set('v', '<leader>d', '"_d', { desc = 'Delete without yanking' })
-- vim.keymap.set('v', '<leader>p', '"_dP', { desc = 'Replace without yanking' })

-- Quick access to mbbill/undotree
vim.keymap.set('n', '<leader>u', '<Cmd>UndotreeToggle<CR>', { desc = 'Toggle undotree' })

-- vim: ts=2 sts=2 sw=2 et
