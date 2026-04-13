return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'
    harpoon:setup()
  end,
  keys = function()
    local keys = {
      {
        '<leader>a',
        function()
          require('harpoon'):list():add()
        end,
        desc = 'Harpoon Add File',
      },
      {
        '<leader>h',
        function()
          local harpoon = require 'harpoon'
          harpoon.ui:toggle_quick_menu(harpoon:list())
        end,
        desc = 'Harpoon Quick Menu',
      },
    }

    for i = 1, 9 do
      local index = i
      local desc = index == 1 and 'Harpoon Jump (1-9)' or 'Harpoon File ' .. index

      table.insert(keys, {
        '<leader>' .. index,
        function()
          require('harpoon'):list():select(index)
        end,
        desc = desc,
      })
    end

    return keys
  end,
}
