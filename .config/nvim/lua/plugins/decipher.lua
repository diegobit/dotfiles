return {
  'MisanthropicBit/decipher.nvim',
  version = '*',
  event = 'VeryLazy',
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
      vim.keymap.set('n', '<leader>ce', function()
        require('decipher').encode_motion_prompt { preview = false }
      end, { desc = '[E]ncode with Motion' }),
      vim.keymap.set('n', '<leader>cd', function()
        require('decipher').decode_motion_prompt { preview = false }
      end, { desc = '[D]ecode with Motion' }),
      -- vim.keymap.set('v', '<leader>ce', function()
      --   require('decipher').encode_selection_prompt { preview = true }
      -- end, { desc = '[E]ncode Selected Text' }),
      -- vim.keymap.set('v', '<leader>cd', function()
      --   require('decipher').decode_selection_prompt { preview = true }
      -- end, { desc = '[D]ecode Selected Text' }),
      vim.keymap.set({ 'v' }, 'gbe', function()
        decipher.encode_selection 'base64'
        local keys = vim.api.nvim_replace_termcodes('<ESC>', true, false, true)
        vim.api.nvim_feedkeys(keys, 'm', false)
      end, { noremap = true, silent = true, desc = '[B]ase64 [E]ncode' }),
      vim.keymap.set({ 'v' }, 'gbd', function()
        decipher.decode_selection 'base64'
      end, { noremap = true, silent = true, desc = '[B]ase64 [D]ecode' }),

      vim.keymap.set({ 'v' }, 'gbse', function()
        decipher.encode_selection 'base64-url-safe'
      end, { noremap = true, silent = true, desc = '[B]ase64 URL [S]afe [E]ncode' }),
      vim.keymap.set({ 'v' }, 'gbsd', function()
        decipher.decode_selection 'base64-url-safe'
      end, { noremap = true, silent = true, desc = '[B]ase64 URL [S]afe [D]ecode' }),

      vim.keymap.set({ 'v' }, 'gue', function()
        decipher.encode_selection 'url'
      end, { noremap = true, silent = true, desc = '[U]RL [E]ncode' }),
      vim.keymap.set({ 'v' }, 'gud', function()
        decipher.decode_selection 'url'
      end, { noremap = true, silent = true, desc = '[U]RL [D]ecode' }),
    }
  end,
}
