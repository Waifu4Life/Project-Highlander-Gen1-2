-- The Start Menu's 16x16 one-bit icons: NikoIchu's CC0 "1-bit Pixel Icons"
-- plus our own Poke Ball for the party, one row of frames in this order.
return {
  sheet = "assets/start_menu_icons_16.png",
  frames = {
    pokedex = 0, party = 1, bag = 2, trainer = 3, save = 4, options = 5,
    pokegear = 6, link = 7, mods = 8, quit = 9, generic = 10, auto = 11,
    quest = 12, map = 13, music = 14, camera = 15, trophy = 16, heart = 17,
    star = 18, tools = 19, key = 20, clock = 21, mail = 22, chat = 23,
    home = 24, shop = 25, chest = 26, battle = 27, potion = 28,
    bicycle = 29, craft = 30, search = 31, pokebox = 32,
  },
  -- CUSTOM ICONS choices, in picker order: { name shown, frame }
  choices = {
    { "AUTO", "auto" }, { "DEX", "pokedex" }, { "PKMN", "party" },
    { "BAG", "bag" }, { "ID", "trainer" }, { "SAVE", "save" },
    { "OPT", "options" }, { "GEAR", "pokegear" }, { "LINK", "link" },
    { "MODS", "mods" }, { "QUIT", "quit" }, { "MENU", "generic" },
    { "QUEST", "quest" }, { "MAP", "map" }, { "MUSIC", "music" },
    { "CAMERA", "camera" }, { "TROPHY", "trophy" }, { "HEART", "heart" },
    { "STAR", "star" }, { "TOOLS", "tools" }, { "KEY", "key" },
    { "CLOCK", "clock" }, { "MAIL", "mail" }, { "CHAT", "chat" },
    { "HOME", "home" }, { "SHOP", "shop" }, { "CHEST", "chest" },
    { "BATTLE", "battle" }, { "POTION", "potion" }, { "BIKE", "bicycle" },
    { "CRAFT", "craft" }, { "SEARCH", "search" }, { "BOX", "pokebox" },
  },
}
