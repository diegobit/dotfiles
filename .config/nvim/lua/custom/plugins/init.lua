-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information
return {
  {
    'monkoose/neocodeium',
    event = 'VeryLazy',
    config = function()
      local neocodeium = require 'neocodeium'
      neocodeium.setup {
        debounce = true,
      }
      vim.keymap.set('i', '<A-a>', neocodeium.accept)
      vim.keymap.set('i', '<A-w>', neocodeium.accept_word)
      vim.keymap.set('i', '<A-l>', neocodeium.accept_line)
      vim.keymap.set('i', '<A-n>', neocodeium.cycle)
      vim.keymap.set('i', '<A-c>', neocodeium.clear)
    end,
  },
  {
    'folke/zen-mode.nvim',
    opts = {
      window = {
        width = 140,
        backdrop = 0.85,
      },
      plugins = {
        options = {
          laststatus = 3,
        },
      },
      -- or leave it empty to use the default settings
      -- refer to the configuration section below
    },
  },
}
