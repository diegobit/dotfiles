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

-- Use spaces in insert mode when pressing <TAB>
vim.o.expandtab = true

-- number of lines to keep when scrolling out of view
vim.opt.scrolloff = 6

-- hide tabline
vim.opt.showtabline = 0

-- Spellcheck languages
vim.opt.spelllang = { 'it', 'en_us' }

-- border for diagnostics
vim.diagnostic.config { float = { border = 'single' } }

-- python
vim.g.python3_host_prog = '$PYENV_ROOT/versions/pynvim/bin/python'

-- aliases when executing commands
vim.cmd('cnoreabbrev llmf !llm -m gemini-1.5-pro-latest -s \'You are an expert software engineer. Your answers are helpful and super concise. If I ask you for a bash command, just output that.\'')
vim.cmd('cnoreabbrev llmp !llm -m gemini-1.5-pro-latest -s \'You are an expert software engineer. Your answers are helpful and concise.\'')

-- vim: ts=2 sts=2 sw=2 et
