return {
  {
    'folke/which-key.nvim',
    version = '*',
    event = 'VeryLazy',
    config = function()
      local wk = require 'which-key'

      wk.setup {
        preset = 'helix',
        icons = {
          separator = '│',
        },
      }

      local mappings = {
        { '<leader>c', group = 'Code' },
        { '<leader>d', group = 'Debug' },
        { '<leader>t', group = 'Toggle' },
        { '<leader>v', group = 'Version Control' },

        -- custom preset for marks
        -- { '`', function() require('which-key').show({ keys = '`', preset = 'modern' }) end },

        -- docs for MisanthropicBit/decipher.nvim
        { 'g/', group = 'URL Encoding', mode = { 'n', 'v' } },
        { 'gb', group = 'Base64 Encoding', mode = { 'n', 'v' } },
        { 'gbs', group = 'URL Safe', mode = { 'n', 'v' } },

        -- Rename commands
        { 'gx', desc = 'Open URL under cursor' },
      }

      for i = 1, 9 do
        if i > 1 then
          table.insert(mappings, { '<leader>' .. i, hidden = true })
        end
      end

      wk.add(mappings)
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
