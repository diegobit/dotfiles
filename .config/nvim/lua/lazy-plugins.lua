-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require('lazy').setup({
  -- NOTE: Plugins can be added with a link (or for a github repo: 'owner/repo' link).
  -- Or using `require 'path/name'`, which will
  -- include a plugin definition from file lua/path/name.lua
  --
  -- Use `opts = {}` to force a plugin to be loaded.

  require 'plugins/gitsigns',

  require 'plugins/which-key',

  require 'plugins/telescope',

  require 'plugins/lspconfig',

  require 'plugins/conform',

  require 'plugins/cmp',

  require 'plugins/vim-sleuth',

  require 'plugins/tokyonight',

  require 'plugins/todo-comments',

  require 'plugins/mini',

  require 'plugins/treesitter',

  require 'plugins/neocodeium',

  require 'plugins/toggleterm',

  require 'plugins/zen-mode',

  require 'plugins/kitty-scrollback',

  -- require 'plugins/indent_line',

  -- require 'plugins/debug',

  -- require 'plugins/autopairs',

  -- require 'plugins/lint',

  -- require 'plugins/neo-tree',

  -- require 'plugins/nvim-possession'
}, {
  ui = {
    -- If you are using a Nerd Font: set icons to an empty table which will use the
    -- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
    icons = vim.g.have_nerd_font and {} or {
      cmd = '⌘',
      config = '🛠',
      event = '📅',
      ft = '📂',
      init = '⚙',
      keys = '🗝',
      plugin = '🔌',
      runtime = '💻',
      require = '🌙',
      source = '📄',
      start = '🚀',
      task = '📌',
      lazy = '💤 ',
    },
  },
})

-- vim: ts=2 sts=2 sw=2 et
