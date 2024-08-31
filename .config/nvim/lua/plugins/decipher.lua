return {
  'MisanthropicBit/decipher.nvim',
  version = '*',
  config = function()
    local decipher = require 'decipher'
    decipher.setup {
      vim.keymap.set('n', '<leader>ube', function()
        decipher.encode_selection 'base64'
      end, { noremap = true, silent = true, desc = '[B]ase64 [E]ncode' }),
      vim.keymap.set('n', '<leader>ubd', function()
        decipher.decode_selection 'base64'
      end, { noremap = true, silent = true, desc = '[B]ase64 [D]ecode' }),

      vim.keymap.set('n', '<leader>ubse', function()
        decipher.encode_selection 'base64-url-safe'
      end, { noremap = true, silent = true, desc = '[B]ase64 URL [S]afe [E]ncode' }),
      vim.keymap.set('n', '<leader>ubsd', function()
        decipher.decode_selection 'base64-url-safe'
      end, { noremap = true, silent = true, desc = '[B]ase64 URL [S]afe [D]ecode' }),

      vim.keymap.set('n', '<leader>uue', function()
        decipher.encode_selection 'url'
      end, { noremap = true, silent = true, desc = '[U]RL [E]ncode' }),
      vim.keymap.set('n', '<leader>uud', function()
        decipher.decode_selection 'url'
      end, { noremap = true, silent = true, desc = '[U]RL [D]ecode' }),
    }
  end,
}
