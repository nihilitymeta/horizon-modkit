-- The example mod's mob and how it spawns; scripts/registry.lua requires this
-- file.
local ns = registry.id -- "example_mod"

-- ENTITY TYPES: a vanilla mob as the template, the attributes that differ,
-- and `goals = "none"`: the mod's scripts give it all of its behaviour
-- (scripts/server/example/mob.lua). Its look and sounds are the pig's; a model and
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
registry.asset(
  "items/example_mob_spawn_egg",
  { model = { type = "minecraft:model", model = ns .. ":item/example_mob_spawn_egg" } }
)
registry.asset(
  "models/item/example_mob_spawn_egg",
  { parent = "minecraft:item/generated", textures = { layer0 = "minecraft:item/pig_spawn_egg" } }
)
registry.data("neoforge/biome_modifier/example_mob_spawns", {
  type = "neoforge:add_spawns",
  biomes = "#minecraft:is_overworld",
  spawners = { { type = ns .. ":example_mob", weight = 8, minCount = 1, maxCount = 2 } },
})

registry.lang("en_us", {
  ["entity.example_mod.example_mob"] = "Example Mob",
  ["item.example_mod.example_mob_spawn_egg"] = "Example Mob Spawn Egg",
})

return nil
