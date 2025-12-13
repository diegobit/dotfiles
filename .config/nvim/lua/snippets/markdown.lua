local ls = require 'luasnip'
local s, f, i = ls.snippet, ls.function_node, ls.insert_node
local fmt = require('luasnip.extras.fmt').fmt

ls.add_snippets('all', {
  s(
    { trig = 'cb', dscr = 'Empty codeblock.' },
    fmt(
      [[```
{}
```]],
      {
        i(0),
      }
    )
  ),
})

ls.add_snippets('all', {
  s({ trig = 'bt', dscr = 'Add triple backticks.' }, {
    f(function()
      return '```'
    end),
  }),
})
