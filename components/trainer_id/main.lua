-- Highlander Trainer ID (Project Highlander Gen1+2): Gold's trainer card for
-- Red, Blue, Yellow and Green. Always on, with no ON/OFF: the game's own
-- Gen 1 card can cut the portrait off on some PCs. Gen 2 keeps the game's
-- own Gold card (with Other Settings' badge additions).
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local gen2 = GameVersion.generation and GameVersion.generation() == 2
  if gen2 then
    mod.log:info("Highlander Trainer ID: Gen 1 only, nothing to do")
    return
  end

  local Card = mod:load("screen.lua")(mod)
  local record = {
    isMenu = true,
    new = function(game, opts) return Card.new(game, opts) end,
  }
  if mod.content.screens:get("TrainerCard") then
    mod.content.screens:override("TrainerCard", record)
  else
    mod.content.screens:register("TrainerCard", record)
  end

  mod.log:info("Highlander Trainer ID ready (Gen 1)")
end
