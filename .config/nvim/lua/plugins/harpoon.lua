return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('harpoon').setup()
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
        require('harpoon').ui:toggle_quick_menu()
      end,
    },
    {
      '<C-h>',
      function()
        require('harpoon'):list():select(1)
      end,
    },
    {
      '<C-t>',
      function()
        require('harpoon'):list():select(2)
      end,
    },
    {
      '<C-n>',
      function()
        require('harpoon'):list():select(3)
      end,
    },
    {
      '<C-s>',
      function()
        require('harpoon'):list():select(4)
      end,
    },
  },
}
