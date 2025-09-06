-- ~/.config/nvim/lua/snippets/datetime.lua
local ls = require 'luasnip'
local s = ls.snippet
local f = ls.function_node

-- ISO 8601 local time: YYYY-MM-DDTHH:MM:SS
local function iso_local()
  return os.date '%Y-%m-%dT%H:%M:%S'
end

local function tz_colon()
  -- "+HHMM" -> "+HH:MM"
  local z = os.date '%z'
  if type(z) ~= 'string' then
    return '+00:00'
  end
  return z:sub(1, 3) .. ':' .. z:sub(4, 5)
end

ls.add_snippets('all', {
  s({ trig = 'disolocal', dscr = 'Put the date in ISO 8601 local time format' }, {
    f(function()
      return iso_local() .. tz_colon()
    end),
  }),
})
