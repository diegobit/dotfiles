-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.opt.number = true
vim.opt.relativenumber = true

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = 'a'

-- Don't show the mode, since it's already in the status line
vim.opt.showmode = false

-- Sync clipboard between OS and Neovim.
--  Schedule the setting after `UiEnter` because it can increase startup-time.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
-- vim.schedule(function()
--   vim.opt.clipboard = 'unnamedplus'
-- end)

-- Enable break indent
vim.opt.breakindent = true

-- Wrap line at character 'breakat' rathern then what fits
vim.opt.lbr = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 500
-- vim.opt.ttimeoutlen = 10

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Default number of spaces per tab
vim.o.shiftwidth = 4
vim.o.tabstop = 4

-- Use spaces in insert mode when pressing <TAB>
vim.o.expandtab = true

-- number of lines to keep when scrolling out of view
vim.opt.scrolloff = 6

-- number of lines to scroll with <C-d> and <C-u>
-- vim.opt.scrolljump = 10 

-- hide tabline
vim.opt.showtabline = 0

-- Spellcheck languages
vim.opt.spelllang = { 'it', 'en_us' }

-- border for diagnostics
-- vim.o.winborder = 'single'
local hover = vim.lsp.buf.hover
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.buf.hover = function()
    return hover({
        border = "single",
        -- max_width = 100,
        max_width = math.floor(vim.o.columns * 0.7),
        max_height = math.floor(vim.o.lines * 0.7),
    })
end
-- disable errors and warnings from appearing in signcolumn
vim.diagnostic.config { float = { border = 'single' }, virtual_text = { current_line = true }, signs = true }
vim.diagnostic.config { float = { border = 'single' }, virtual_text = true, signs = false }

-- set 2 signcolumns
-- vim.opt.signcolumn = 'yes:2'

-- python
vim.g.python3_host_prog = '$HOME/.local/share/nvim/pyvenv/bin/python3'

-- vim: ts=2 sts=2 sw=2 et
