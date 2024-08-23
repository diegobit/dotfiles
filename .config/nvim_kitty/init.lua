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
