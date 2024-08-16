-------------------------------
-- A variable for the Hyper Mode
-------------------------------

k = hs.hotkey.modal.new({}, 'F17')

-------------------------------
-- Hyper global state
-------------------------------
isHyperPressed = false

-- All the keys to handle
-- except with ' instead of " (not sure why but it didn't work otherwise)
-- and the function keys greater than F12 removed.
-- list: http://www.hammerspoon.org/docs/hs.keycodes.html#map -- look for hs.keycodes.map
local keys = {
  "a",
  "b",
  -- "c",
  "d",
  -- "e",
  -- "f",
  -- "g",
  -- "h",
  "i",
  "j",
  "k",
  "l",
  -- "m",
  -- "n",
  -- "o",
  -- "p",
  -- "q",
  -- "r",
  "s",
  -- "t",
  -- "u",
  -- "v",
  "w",
  -- "x",
  -- "y",
  -- "z",
  -- "0",
  -- "1",
  -- "2",
  -- "3",
  -- "4",
  -- "5",
  -- "6",
  -- "7",
  -- "8",
  -- "9",
  -- "`",
  -- "=",
  -- "-",
  -- "]",
  -- "[",
  -- "\'",
  -- ";",
  -- "\\",
  -- ",",
  -- "/",
  -- ".",
  -- "§",
  -- "f1",
  -- "f2",
  -- "f3",
  -- "f4",
  -- "f5",
  -- "f6",
  -- "f7",
  -- "f8",
  -- "f9",
  -- "f10",
  -- "f11",
  -- "f12",
  -- "pad.",
  -- "pad*",
  -- "pad+",
  -- "pad/",
  -- "pad-",
  -- "pad=",
  -- "pad0",
  -- "pad1",
  -- "pad2",
  -- "pad3",
  -- "pad4",
  -- "pad5",
  -- "pad6",
  -- "pad7",
  -- "pad8",
  -- "pad9",
  -- "padclear",
  -- "padenter",
  -- "return",
  -- "tab",
  -- "space",
  -- "delete",
  -- "help",
  -- "home",
  -- "pageup",
  -- "forwarddelete",
  -- "end",
  -- "pagedown",
  -- "left",
  -- "right",
  -- "down",
  -- "up"
}


-- sends a key event with all modifiers
-- bool -> string -> void -> side effect
local hyper = function(isdown)
  return function(key)
    return function()
      -- k.triggered = true
      local event = hs.eventtap.event.newKeyEvent({'cmd', 'alt', 'shift', 'ctrl'},
                                                  key,
                                                  isdown)
      event:post()
    end
  end
end

local hyperDown = hyper(true)
local hyperUp = hyper(false)

-- actually bind a key
local hyperBind = function(key)
  k:bind('', key, msg, hyperDown(key), hyperUp(key), nil)
end

-- bind all the keys in the huge keys table
for index, key in pairs(keys) do hyperBind(key) end

-- Enter Hyper Mode when F18 (Hyper) is pressed
  local pressedF18 = function()
    -- k.triggered = false
    isHyperPressed = true
    k:enter()
  end

-- Leave Hyper Mode when F18 (Hyper) is pressed,
-- send the chosen key if no other keys are pressed.
local releasedF18 = function()
  isHyperPressed = false
  k:exit()
  -- if not k.triggered then
  --   hs.eventtap.keyStroke({}, 'ESCAPE', no_delay)
  -- end
end

-- Bind the Hyper key
local f18 = hs.hotkey.bind({}, 'F18', pressedF18, releasedF18)

