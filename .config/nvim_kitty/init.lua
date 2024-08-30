-- Simple settings for being loaded for kitty scrollback, see:
-- https://github.com/mikesmithgh/kitty-scrollback.nvim?tab=readme-ov-file#separate-neovim-configuration
--
-- Global clipboard not enabled because it can be done with <space>y
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.updatetime = 250
vim.opt.swapfile = false

-- Quick exit
vim.keymap.set("i", "<C-q>", "<Cmd>q<CR>")
vim.keymap.set("n", "<C-q>", "<Cmd>q<CR>")

vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/kitty-scrollback.nvim") -- lazy.nvim

-- Lazy.nvim bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("error cloning lazy.nvim:\n" .. out)
	end
end ---@diagnostic disable-next-line: undefined-field
vim.opt.rtp:prepend(lazypath)
vim.g.loaded_2html_plugin = 1
vim.g.loaded_getscript = 1
vim.g.loaded_getscriptPlugin = 1
vim.g.loaded_gzip = 1
vim.g.loaded_logiPat = 1
vim.g.loaded_man = 1
vim.g.loaded_matchit = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_remote_plugins = 1
vim.g.loaded_rplugin = 1
vim.g.loaded_rrhelper = 1
vim.g.loaded_shada_plugin = 1
vim.g.loaded_shada_plugin = 1
vim.g.loaded_spec = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_tar = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_vimball = 1
vim.g.loaded_vimballPlugin = 1
vim.g.loaded_zip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_load_black = 1
vim.g.loaded_gtags = 1
vim.g.loaded_gtags_cscope = 1
vim.g.loaded_netrwFileHandlers = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_netrwSettings = 1

-- Run lazy.vim and kitty-scrollback
require("lazy").setup({
	require("kitty-scrollback").setup({
		{
			enabled = true,
			lazy = true,
			cmd = { "KittyScrollbackGenerateKittens", "KittyScrollbackCheckHealth" },
			event = { "User KittyScrollbackLaunch" },
			version = "^5.0.0",
		},
	}),
})
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_pythonx_provider = 0
