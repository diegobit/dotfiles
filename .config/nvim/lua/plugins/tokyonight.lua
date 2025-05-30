return {
  { -- You can easily change to a different colorscheme.
    -- Change the name of the colorscheme plugin below, and then
    -- change the command in the config to whatever the name of that colorscheme is.
    --
    -- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
    'folke/tokyonight.nvim',
    version = '*',
    priority = 1000, -- Make sure to load this before all the other start plugins.
    init = function()
      -- require('tokyonight').setup {
      -- on_colors = function(colors)
      --   colors.bg_sidebar = '#000000'
      --   colors.bg_float = '#000000'
      -- end,
      -- }

      -- Load the colorscheme here.
      -- Like many other themes, this one has different styles, and you could load
      -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
      vim.cmd.colorscheme 'tokyonight'

      -- Background
      -- vim.cmd.hi 'Normal guibg=#161720'
      -- Comments and line numbers
      vim.cmd.hi 'Comment guifg=#95607e'
      -- vim.cmd.hi 'LineNr  guifg=#95606a'
      -- old line numbers: 4E567B
      vim.cmd.hi 'LineNr guifg=#58607e'
      vim.cmd.hi 'LineNrAbove guifg=#58607e'
      vim.cmd.hi 'LineNrBelow guifg=#58607e'
      -- change line highlight background
      vim.cmd.hi 'CursorLine guibg=#2d314a'
      -- Change selection color
      vim.cmd.hi 'Visual guibg=#405490'
      -- unused variables color
      vim.cmd.hi 'DiagnosticUnnecessary guifg=#80869d'

      -- Change colors of neocodeium
      vim.cmd.hi 'NeoCodeiumSuggestion guifg=#80869d'

      -- Change context color for echasnovski/mini.diff overlay
      vim.cmd.hi 'MiniDiffOverContext guifg=#454c6d'
      vim.cmd.hi 'MiniDiffSignAdd guifg=#50a077'
      vim.cmd.hi 'MiniDiffSignChange guifg=#6388c4'
      vim.cmd.hi 'MiniDiffSignDelete guifg=#b8616f'

      -- Change color for lukas-reineke/indent-blankline.nvim
      vim.cmd.hi 'IblIndent guifg=#333548'
      vim.cmd.hi 'IblScope guifg=#556d91'
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
