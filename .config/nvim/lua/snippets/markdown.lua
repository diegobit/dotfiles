local ls = require 'luasnip'
local s, i = ls.snippet, ls.insert_node
local fmt = require('luasnip.extras.fmt').fmt

ls.add_snippets('all', {
  s(
    { trig = 'cb', dscr = 'Markdown fenced code block' },
    fmt(
      [[```{}
{}
```]],
      {
        i(1, 'lang'),
        i(0),
      }
    )
  ),
})
