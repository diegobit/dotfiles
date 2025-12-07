local ls = require "luasnip"
local s, f, i = ls.snippet, ls.function_node, ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

ls.add_snippets("all", {
  s({ trig = "qn", dscr = "Add a new quicknote" }, fmt([[

{}
-------------
{}


]], {
    f(function() return os.date("%b %d, %Y") end),
    i(0),  -- <— cursor here
  })),
})

ls.add_snippets('all', {
  s({ trig = 'td', dscr = 'Add a todo' }, {
    f(function()
      return '- [ ] '
    end),
  }),
})
