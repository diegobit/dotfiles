return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    harpoon:setup()
  end,
  keys = {
    {
      '<C-h>',
      function()
        require('harpoon'):list():add()
      end,
    },
    {
      '<C-e>',
      function()
        require('harpoon').ui:toggle_quick_menu(require('harpoon'):list())
      end,
      desc = 'Open harpoon window',
    },
    {
      '<C-j>',
      function()
        require('harpoon'):list():select(1)
      end,
    },
    {
      '<C-k>',
      function()
        require('harpoon'):list():select(2)
      end,
    },
    {
      '<C-l>',
      function()
        require('harpoon'):list():select(3)
      end,
    },
    {
      '<C-;>',
      function()
        require('harpoon'):list():select(4)
      end,
    },
  },
}
