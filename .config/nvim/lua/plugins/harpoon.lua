return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  -- dependencies = { 'nvim-telescope/telescope.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    harpoon:setup()
    -- require('harpoon'):setup()

    local ok, telescope = pcall(require, 'telescope')
    if ok then
      telescope.load_extension 'harpoon'
    end
  end,
  keys = {
    {
      '<C-a>',
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
      '<C-h>',
      function()
        require('harpoon'):list():select(1)
      end,
    },
    {
      '<C-j>',
      function()
        require('harpoon'):list():select(2)
      end,
    },
    {
      '<C-k>',
      function()
        require('harpoon'):list():select(3)
      end,
    },
    {
      '<C-l>',
      function()
        require('harpoon'):list():select(4)
      end,
    },
    {
      '<C-;>',
      function()
        require('harpoon'):list():select(5)
      end,
    },
  },
}
