-- Move Colours: two rows shown on the BATTLE SCREEN page.
--   COLORED MOVES      move animations take the colour of the move's type
--   COLORED POKEBALLS  thrown balls, the party ball row and the Pokemon
--                      Center machine use each ball's own colours
-- Looks only: moves, PP and how battles work stay the game's.
return function(mod)
  mod.options:define({
    { key = "colored_pokeballs", label = "COLORED POKEBALLS", type = "toggle", default = true },
    { key = "colored_pokemoves", label = "COLORED MOVES", type = "toggle", default = true },
  })

  -- Each half loads on its own, so one failing never takes the other down.
  for _, part in ipairs({
    { file = "colored_pokeballs.lua", name = "colored pokeballs" },
    { file = "colored_pokemoves.lua", name = "colored pokemoves" },
  }) do
    local ok, err = pcall(function() mod:load(part.file)(mod) end)
    if not ok then mod.log:error("%s failed: %s", part.name, tostring(err)) end
  end
end
