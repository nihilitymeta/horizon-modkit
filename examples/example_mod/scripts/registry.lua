-- Example Mod: what it adds, declared once when the game starts. One of each
-- kind the registry takes (an item, a block, an entity type, a mob effect, a
-- creative tab) with the data and assets beside them (a recipe, loot, a tag,
-- models, the lang file), all as Lua tables: this mod ships no JSON and no
-- PNG, its looks are vanilla's textures. Guides: docs/guides/items.md,
-- blocks.md, mobs.md, spawning.md. A change here needs the game restarted;
-- scripts/init.lua and the files it requires reload with /reload.
-- See it in game: the Example Mod tab of the creative inventory.
local ns = registry.id   -- "example_mod"

-- ITEMS: a vanilla template (its data components: stack size, food,
-- durability...) and what differs; a look under assets/, as the client reads
-- it (items/<name>: which model; models/item/<name>: the model). The feather
-- gets its callbacks in scripts/example/item.lua.
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

-- BLOCKS: a template, a state property of the block's own (`lit`), random
-- ticks (the template never ticks), an item for it, a blockstate that picks a
-- model per state, loot, a tag so a pickaxe mines it, a recipe. Its
-- behaviour is in scripts/example/block.lua.
registry.block("example_block", {
  template = "minecraft:iron_block",
  properties = { hardness = 2.0, random_ticks = true },
  state_properties = { lit = { type = "boolean" } },
  default_state = { lit = "false" },
  item = true,
  components = { ["minecraft:max_stack_size"] = 16 },
})
registry.asset("blockstates/example_block", { variants = {
  ["lit=false"] = { model = ns .. ":block/example_block" },
  ["lit=true"] = { model = ns .. ":block/example_block_lit" },
} })
registry.asset("models/block/example_block", { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/iron_block" } })
registry.asset("models/block/example_block_lit", { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/sea_lantern" } })
registry.asset("items/example_block", { model = { type = "minecraft:model", model = ns .. ":block/example_block" } })
registry.data("loot_table/blocks/example_block", {
  type = "minecraft:block",
  pools = { {
    condition = { type = "minecraft:survives_explosion" },
    entries = { { type = "minecraft:item", name = ns .. ":example_block" } },
    rolls = 1,
  } },
  random_sequence = ns .. ":blocks/example_block",
})
registry.data("minecraft:tags/block/mineable/pickaxe", { values = { ns .. ":example_block" } })
registry.data("recipe/example_block", {
  type = "minecraft:crafting_shaped",
  category = "building",
  pattern = { "II", "II" },
  key = { I = "minecraft:iron_ingot" },
  result = { id = ns .. ":example_block" },
})

-- ENTITY TYPES: a vanilla mob as the template, the attributes that differ,
-- and `goals = "none"`: the mod's scripts give it all of its behaviour
-- (scripts/example/mob.lua). Its look and sounds are the pig's; a model and
-- an animation set of the mod's own go here too (docs/guides/mobs.md). Its
-- loot table, or the template's without one.
registry.entity_type("example_mob", {
  template = "minecraft:pig",
  attributes = { max_health = 16, movement_speed = 0.3 },
  goals = "none",
})
registry.data("loot_table/entities/example_mob", {
  type = "minecraft:entity",
  pools = { { rolls = 1, entries = { { type = "minecraft:item", name = "minecraft:porkchop" } } } },
})
-- SPAWNING (docs/guides/spawning.md): a spawn egg is an item whose id ends
-- in _spawn_egg and names the kind; natural spawns are a biome modifier.
registry.item("example_mob_spawn_egg", { template = "minecraft:pig_spawn_egg" })
registry.asset("items/example_mob_spawn_egg", { model = { type = "minecraft:model", model = ns .. ":item/example_mob_spawn_egg" } })
registry.asset("models/item/example_mob_spawn_egg", { parent = "minecraft:item/generated", textures = { layer0 = "minecraft:item/pig_spawn_egg" } })
registry.data("neoforge/biome_modifier/example_mob_spawns", {
  type = "neoforge:add_spawns",
  biomes = "#minecraft:is_overworld",
  spawners = { { type = ns .. ":example_mob", weight = 8, min_count = 1, max_count = 2 } },
})

-- MOB EFFECTS: a category and a colour; the scripts give it
-- (scripts/example/effects.lua). It does nothing on its own.
registry.mob_effect("example_effect", { category = "beneficial", color = 0x7FD4FF })

-- CREATIVE TABS: a title, an icon, the items in order.
registry.creative_tab("example", {
  title = "Example Mod",
  icon = ns .. ":example_item",
  items = { ns .. ":example_item", ns .. ":example_snack", ns .. ":example_block", ns .. ":example_mob_spawn_egg" },
})

-- NAMES: the lang file, as assets/example_mod/lang/en_us.json.
registry.asset("lang/en_us", {
  ["item.example_mod.example_item"] = "Example Feather",
  ["item.example_mod.example_snack"] = "Example Snack",
  ["item.example_mod.example_mob_spawn_egg"] = "Example Mob Spawn Egg",
  ["block.example_mod.example_block"] = "Example Lamp",
  ["entity.example_mod.example_mob"] = "Example Mob",
  ["effect.example_mod.example_effect"] = "Exemplary",
})
