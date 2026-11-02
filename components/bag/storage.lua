-- Highlander Bag storage: room for 255 different items (the whole bag, in
-- both generations: Gen 2's pockets share it) and the item PC raised to match. Items
-- that keep a single slot (every Gen 2 item) can stack up to 999; Gen 1
-- items over 99 take a second slot the way the cartridge does it.
--
-- Always on, even with HIGHLANDER BAG off: a bag already holding more than
-- the cartridge allowed must keep working.
return function(mod)
  local Bag = require("src.inventory.Bag")
  local GameVersion = require("src.core.GameVersion")

  local SLOTS, STACK = 255, 999
  local gen1 = not (GameVersion.generation and GameVersion.generation() == 2)

  if not Bag.__highlanderBagStorage then
    Bag.__highlanderBagStorage = true

    local capacity = Bag.capacity
    Bag.capacity = function(data, pocket)
      local ok, value = pcall(capacity, data, pocket)
      return math.max(ok and tonumber(value) or 0, SLOTS)
    end

    -- Items that don't split into stacks of 99 (all of Gen 2, Gen 1 items
    -- with a pocket) are refused by the game past 99: let them reach 999.
    -- Gen 2: the 255 is for the whole bag, all pockets together. A NEW item
    -- needs a free slot in it (more of one already owned always fits).
    local function totalSlots(save, data)
      local inv = save.inventory or {}
      local ok, n = pcall(Bag.storeSlots, inv, data, function(item)
        return not Bag.isBadge(item) and (tonumber(inv[item]) or 0) > 0
      end, save.bagStacks)
      return ok and tonumber(n) or 0
    end
    local add = Bag.add
    Bag.add = function(save, id, qty, data)
      if not gen1 and type(save) == "table" and type(id) == "string"
          and not Bag.isBadge(id) and type(save.inventory) == "table"
          and (tonumber(save.inventory[id]) or 0) <= 0
          and totalSlots(save, data) >= SLOTS then
        return false
      end
      if add(save, id, qty, data) then return true end
      if type(save) ~= "table" or type(id) ~= "string" or Bag.isBadge(id) then
        return false
      end
      local inv = save.inventory
      if type(inv) ~= "table" then return false end
      local items = (data and data.items) or (require("src.core.Data").items)
      local def = items and items[id]
      if gen1 and not (def and def.pocket) then return false end
      local amount = tonumber(qty) or 1
      local old = tonumber(inv[id]) or 0
      local total = old + amount
      if amount < 1 or total > STACK then return false end
      if old <= 0 then
        local pocket = Bag.pocketOf(id, data)
        if Bag.slots(save, data, pocket) >= Bag.capacity(data, pocket) then
          return false
        end
      end
      inv[id] = total
      Bag.order(save, data) -- files a new id at the end of the bag
      return true
    end
  end

  -- Gen 1's item PC holds as many different items as the bag.
  if not gen1 then return end
  mod.events:always("game.ready", function(event)
    local game = event and (event.game or event)
    local data = type(game) == "table" and game.data
    if type(data) ~= "table" then return end
    data.field = data.field or {}
    data.field.pcItemCap = math.max(tonumber(data.field.pcItemCap) or 50, SLOTS)
  end)
end
