-- Highlander Bag (Project Highlander Gen1+2): Gold/Silver/Crystal's PACK in
-- both generations -- built new for Red/Blue/Yellow/Green, the game's own
-- PACK (with money, the slot counter and Start: Sort) in Gold/Silver/Crystal.
-- OTHER SETTINGS > HIGHLANDER BAG: OFF (the game's own bag), a default
-- pocket to open on, or LAST OPENED (the default). The bigger bag (255 items) stays on either way.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local gen2 = GameVersion.generation and GameVersion.generation() == 2

  mod:load("storage.lua")(mod)
  local C = mod:load("common.lua")(mod)

  local function constructor(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end

  -- Wrap whatever builds the screen today (another mod, or the game).
  local function decorateScreen(id, nativePath, decorate)
    local inherited = constructor(mod.content.screens:get(id))
    local record = {
      isMenu = true,
      new = function(game, ...)
        local make = inherited or require(nativePath).new
        return decorate(make(game, ...), ...)
      end,
    }
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end

  if gen2 then
    local G2 = mod:load("gen2.lua")(mod, C)
    decorateScreen("Gen2PackMenu", "src.ui.gen2.PackMenu", G2.decorate)
  else
    local G1 = mod:load("gen1.lua")(mod, C)
    decorateScreen("BagMenu", "src.ui.BagMenu", G1.decorate)
    decorateScreen("ShopMenu", "src.ui.ShopMenu", G1.decorateShop)
  end
  mod.log:info("Highlander Bag ready (Gen %d)", gen2 and 2 or 1)
end
