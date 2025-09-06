return {
  'L3MON4D3/LuaSnip',
  dependencies = { 'rafamadriz/friendly-snippets' },
  config = function()
    -- Load custom Lua snippets
    require('luasnip.loaders.from_lua').load {
      paths = '~/.config/nvim/lua/snippets',
    }
    print("LuaSnip custom snippets loaded!")
  end,
}
