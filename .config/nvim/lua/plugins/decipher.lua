-- Define keymaps here so that we can load the plugin lazily

vim.keymap.set('n', '<leader>ce', function()
  require('decipher').encode_motion_prompt { preview = false }
end, { desc = 'Encode (w/ motion)' })
vim.keymap.set('n', '<leader>cd', function()
  require('decipher').decode_motion_prompt { preview = false }
end, { desc = 'Decode (w/ motion)' })
vim.keymap.set('x', '<leader>ce', function()
  require('decipher').encode_selection_prompt { preview = false }
end, { desc = 'Encode Selected Text' })
vim.keymap.set('x', '<leader>cd', function()
  require('decipher').decode_selection_prompt { preview = false }
end, { desc = 'Decode Selected Text' })

return {
  'MisanthropicBit/decipher.nvim',
  -- version = '*',
  branch = 'add-commands',
  lazy = true, -- Load with keymap
  cmd = {
    'DecipherEncode',
    'DecipherDecode',
    'DecipherVersion',
  },
  config = function()
    local decipher = require 'decipher'
    decipher.setup {
      active_codecs = 'all',
      float = {
        border = {
          { '┌', 'FloatBorder' },
          { '─', 'FloatBorder' },
          { '┐', 'FloatBorder' },
          { '│', 'FloatBorder' },
          { '┘', 'FloatBorder' },
          { '─', 'FloatBorder' },
          { '└', 'FloatBorder' },
          { '│', 'FloatBorder' },
        },

        mappings = {
          close = 'q',
          apply = 'y',
          jsonpp = 'J', -- Key to prettily format contents as json if possbile
          help = '?',
        },
        enter = true,
        options = {},
      },
    }
  end,
}
