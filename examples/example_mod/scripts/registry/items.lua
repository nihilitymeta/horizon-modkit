-- The example mod's items; scripts/registry.lua requires this file.
local ns = registry.id   -- "example_mod"

-- ITEMS: a vanilla template (its data components: stack size, food,
-- durability...) and what differs; a look under assets/, as the client reads
-- it (items/<name>: which model; models/item/<name>: the model). The feather
-- gets its callbacks in scripts/server/example/item.lua.
registry.item("example_item", { template = "minecraft:feather", max_stack_size = 16, rarity = "uncommon" })
registry.asset("items/example_item", { model = { type = "minecraft:model", model = ns .. ":item/example_item" } })
registry.asset("models/item/example_item", { parent = "minecraft:item/generated", textures = { layer0 = "minecraft:item/feather" } })
registry.data("recipe/example_item", {
  type = "minecraft:crafting_shapeless",
  category = "misc",
  ingredients = { "minecraft:feather", "minecraft:glowstone_dust" },
  result = { id = ns .. ":example_item", count = 2 },
})
-- A snack: a cookie by template, so it is eaten (on_use_start, on_finished).
registry.item("example_snack", { template = "minecraft:cookie" })
registry.asset("items/example_snack", { model = { type = "minecraft:model", model = ns .. ":item/example_snack" } })
registry.asset("models/item/example_snack", { parent = "minecraft:item/generated", textures = { layer0 = "minecraft:item/cookie" } })
-- The lure: a bone by template with a bone's look; used on a block it calls
-- an example mob out of it, and a zombie struck with it becomes one
-- (scripts/server/example/lure.lua).
registry.item("example_lure", { template = "minecraft:bone", max_stack_size = 16, rarity = "rare" })
registry.asset("items/example_lure", { model = { type = "minecraft:model", model = ns .. ":item/example_lure" } })
registry.asset("models/item/example_lure", { parent = "minecraft:item/generated", textures = { layer0 = "minecraft:item/bone" } })
registry.data("recipe/example_lure", {
  type = "minecraft:crafting_shapeless",
  category = "misc",
  ingredients = { "minecraft:bone", "minecraft:wheat" },
  result = { id = ns .. ":example_lure", count = 2 },
})

-- NAMES: registry.lang adds them to assets/example_mod/lang/en_us.json, with
-- the names the other registry modules give.
registry.lang("en_us", {
  ["item.example_mod.example_item"] = "Example Feather",
  ["item.example_mod.example_snack"] = "Example Snack",
  ["item.example_mod.example_lure"] = "Example Lure",
})

return nil
