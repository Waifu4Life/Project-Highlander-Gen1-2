-- Paged text: the mod's own NPC lines wait for A every 2 lines.
--
-- The game's text box only stops for a button at a page break (\f). Inside
-- a page, a paragraph longer than the box's two lines is soft-wrapped and
-- the extra lines just keep typing and scrolling up, so a long speech by
-- Oak, the Karate Master or the Super Nerd ran past before it could be read.
--
-- paged(game, text) wraps the text exactly like the box will (the game's
-- own TextBox.paginate, at the box's width, names already filled in) and
-- puts a page break after every 2 lines, so each box full of text waits
-- for A (or B) like the original games' own speeches.
--
-- Text using the game's special markers ({PROMPT}, {DONE}, \v scrolls,
-- pauses) is handed back untouched.
return function()
  local PAUSE = "\1"

  local function textBox()
    local ok, TB = pcall(require, "src.render.TextBox")
    if ok and type(TB) == "table" and type(TB.paginate) == "function" then return TB end
    return nil
  end

  local function maxCols()
    local ok, Theme = pcall(require, "src.ui.Theme")
    local box = ok and type(Theme) == "table" and Theme.textBox
    return type(box) == "table" and tonumber(box.maxCols) or 18
  end

  return function(game, text)
    if type(text) ~= "string" or text == "" then return text end
    if text:find("{PROMPT}", 1, true) or text:find("{DONE}", 1, true)
        or text:find("\v", 1, true) or text:find(PAUSE, 1, true) then
      return text
    end
    local TB = textBox()
    if not TB then return text end
    local ok, result = pcall(function()
      local full = text
      if type(TB.substitute) == "function" then full = TB.substitute(game, text) end
      local pages = TB.paginate(full, maxCols())
      local chunks = {}
      for _, page in ipairs(pages) do
        local lines = {}
        for _, line in ipairs(page) do
          line = line:gsub("%s+$", "")
          if line ~= "" then lines[#lines + 1] = line end
        end
        for i = 1, #lines, 2 do
          chunks[#chunks + 1] = lines[i + 1] and (lines[i] .. "\n" .. lines[i + 1]) or lines[i]
        end
      end
      if #chunks == 0 then return text end
      return table.concat(chunks, "\f")
    end)
    return ok and result or text
  end
end
