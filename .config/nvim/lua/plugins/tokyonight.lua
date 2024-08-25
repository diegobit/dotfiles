return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight-night'

      -- Background
      -- vim.cmd.hi 'Normal guibg=#161720'
      -- Comments and line numbers
      vim.cmd.hi 'Comment guifg=#95606a'
      -- vim.cmd.hi 'LineNr  guifg=#95606a'
      vim.cmd.hi 'LineNrAbove guifg=#4E567B'
      vim.cmd.hi 'LineNrBelow guifg=#4E567B'
      -- change line highlight background
      vim.cmd.hi 'CursorLine guibg=#232738'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
