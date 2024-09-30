-- NOTE: Plugins can also be configured to run Lua code when they are loaded.
--
-- This is often very useful to both group configuration, as well as handle
-- lazy loading plugins that don't need to be loaded immediately at startup.
--
-- For example, in the following configuration, we use:
--  event = 'VimEnter'
--
-- which loads which-key before all the UI elements are loaded. Events can be
-- normal autocommands events (`:help autocmd-events`).
--
-- Then, because we use the `config` key, the configuration only runs
-- after the plugin has been loaded:
--  config = function() ... end

return {
  { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    version = '*',
    event = 'VeryLazy', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require('which-key').setup {
        preset = 'helix',
      }

      -- Document existing key chains
      require('which-key').add {
        { '<leader>c', group = 'Code' },
        -- { '<leader>d', group = 'Debug' },
        { '<leader>s', group = 'Search' },
        { '<leader>t', group = 'Toggle' },

        -- docs for MisanthropicBit/decipher.nvim
        { 'g/', group = 'URL encoding', mode = { 'n', 'v' } },
        { 'gb', group = 'Base64 encoding', mode = { 'n', 'v' } },
        { 'gbs', group = 'URL Safe', mode = { 'n', 'v' } },
      }
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
