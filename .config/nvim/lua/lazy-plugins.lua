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

  -- require 'plugins/gitsigns',
  require 'plugins/which-key',

  require 'plugins/telescope',

  require 'plugins/lspconfig',

  require 'plugins/conform',

  require 'plugins/luasnip',

  require 'plugins/cmp',

  require 'plugins/vim-sleuth',

  require 'plugins/tokyonight',

  require 'plugins/todo-comments',

  require 'plugins/mini',

  require 'plugins/treesitter',

  -- require 'plugins/neocodeium',

  -- require 'plugins/toggleterm',

  require 'plugins/zen-mode',

  -- require 'plugins/kitty-scrollback',

  require 'plugins/undotree',

  require 'plugins/harpoon',

  require 'plugins/indent-blankline',

  require 'plugins/debug',

  require 'plugins/autopairs',

  require 'plugins/lint',

  require 'plugins/markdown-preview',

  require 'plugins/telescope-tabs',

  require 'plugins/rest',

  require 'plugins/oil',

  require 'plugins/vim-fugitive',

  require 'plugins/vim-flog',

  require 'plugins/decipher',

  require 'plugins/vim-be-good',

  -- require 'plugins/bg',

  require 'plugins/bullets',

  require 'plugins/outline',

  require 'plugins/trouble',

  require 'plugins/vim-plist',

  require 'plugins/gp',

  require 'plugins/jupytext',

  require 'plugins/uv'
}, {
  ui = {
    icons = {},
    border = 'rounded',
  },
  performance = {
    rtp = {
      disabled_plugins = {
        'netrwFileHandlers',
        'netrwPlugin',
        'netrwSettings',
        'perl_provider',
        'ruby_provider',
        'node_provider',
        'python3_provider',
        'pythonx_provider',
        'remote_plugins',
      },
    },
  },
})

-- vim: ts=2 sts=2 sw=2 et
