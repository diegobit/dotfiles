-- Define keymaps here so that we can load the plugin lazily

---- Broken for now
-- vim.keymap.set('n', '<leader>ce', function()
--   require('decipher').encode_motion_prompt { preview = false }
-- end, { desc = 'Encode (w/ motion)' })
-- vim.keymap.set('n', '<leader>cd', function()
--   require('decipher').decode_motion_prompt { preview = false }
-- end, { desc = 'Decode (w/ motion)' })
-- vim.keymap.set('v', '<leader>ce', function()
--   require('decipher').encode_selection_prompt { preview = true }
-- end, { desc = 'Encode Selected Text' }),
-- vim.keymap.set('v', '<leader>cd', function()
--   require('decipher').decode_selection_prompt { preview = true }
-- end, { desc = 'Decode Selected Text' }),

vim.keymap.set({ 'v' }, 'gbe', function()
  require('decipher').encode_selection ('base64', { preview = false })
  local keys = vim.api.nvim_replace_termcodes('<ESC>', true, false, true)
  vim.api.nvim_feedkeys(keys, 'm', false)
end, { noremap = true, silent = true, desc = 'Encode' })
vim.keymap.set({ 'v' }, 'gbd', function()
  require('decipher').decode_selection ('base64', { preview = false })
end, { noremap = true, silent = true, desc = 'Decode' })

vim.keymap.set({ 'v' }, 'gbse', function()
  require('decipher').encode_selection ('base64-url-safe', { preview = false })
end, { noremap = true, silent = true, desc = 'Encode' })
vim.keymap.set({ 'v' }, 'gbsd', function()
  require('decipher').decode_selection ('base64-url-safe', { preview = false })
end, { noremap = true, silent = true, desc = 'Decode' })

vim.keymap.set({ 'v' }, 'g/e', function()
  require('decipher').encode_selection ('url', { preview = false })
end, { noremap = true, silent = true, desc = 'Encode' })
vim.keymap.set({ 'v' }, 'g/d', function()
  require('decipher').decode_selection ('url', { preview = false })
end, { noremap = true, silent = true, desc = 'Decode' })

return {
  'MisanthropicBit/decipher.nvim',
  version = '*',
  -- event = 'VeryLazy',
  lazy = true, -- Load with keymap
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
