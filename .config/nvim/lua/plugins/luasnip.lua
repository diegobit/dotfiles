return {
  'L3MON4D3/LuaSnip',
  event = 'VeryLazy',
  build = (function()
    return 'make install_jsregexp'
  end)(),
  dependencies = {
    {
      'rafamadriz/friendly-snippets',
      config = function()
        require('luasnip.loaders.from_vscode').lazy_load()
      end,
    },
  },
  config = function()
    -- Load custom Lua snippets
    require('luasnip.loaders.from_lua').load {
      paths = '~/.config/nvim/lua/snippets',
    }
    -- print("LuaSnip custom snippets loaded!")
  end,
}
