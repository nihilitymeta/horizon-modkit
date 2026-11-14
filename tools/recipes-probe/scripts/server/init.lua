-- Pushes data pack files when the server builds its data tables
-- (`data_pack_files`), so the game's recipes change from Lua: a replacement
-- for a vanilla recipe, a filter that removes another, and a new recipe. An
-- untouched vanilla recipe (oak planks) is the control the check compares.
-- tools/recipes-check.sh reads the game's own answers after /reload.
local STICK = [[
{"type": "minecraft:crafting_shaped", "group": "sticks",
 "key": {"#": "#minecraft:planks"}, "pattern": ["#", "#"],
 "result": {"count": 7, "id": "minecraft:stick"}}
]]
local FILTER = [[
{"filters": [{"id": "minecraft:stone_pickaxe", "remove": true}]}
]]
local PROBE = [[
{"type": "minecraft:crafting_shapeless", "ingredients": ["minecraft:dirt"],
 "result": {"count": 1, "id": "minecraft:diamond"}}
]]

-- Pushed on every load: a world's first open and each `/reload`. The check
-- waits for the reload's own line, so what it judges is what a load pushed.
horizon.on("data_pack_files", function(event)
  local files = {
    { path = "recipe/minecraft:stick", data = STICK },
    { path = "recipe_filter/recipes_probe:no_stone_pickaxe", data = FILTER },
    { path = "recipe/recipes_probe:probe_item", data = PROBE },
  }
  for _, file in ipairs(files) do
    event.files[#event.files + 1] = file
  end
  horizon.log(("RECIPE push ok files=%d"):format(#event.files))
end)
