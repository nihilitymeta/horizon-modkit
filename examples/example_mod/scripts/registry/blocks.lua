-- The example mod's blocks; scripts/registry.lua requires this file.
local ns = registry.id -- "example_mod"

-- BLOCKS: a template, a state property of the block's own (`lit`), random
-- ticks (the template never ticks), an item for it, a blockstate that picks a
-- model per state, loot, a tag so a pickaxe mines it, a recipe. Its
-- behaviour is in scripts/server/example/block.lua.
registry.block("example_block", {
  template = "minecraft:iron_block",
  properties = { hardness = 2.0, random_ticks = true },
  state_properties = { lit = { type = "boolean" } },
  default_state = { lit = "false" },
  item = true,
  components = { ["minecraft:max_stack_size"] = 16 },
})
registry.asset("blockstates/example_block", {
  variants = {
    ["lit=false"] = { model = ns .. ":block/example_block" },
    ["lit=true"] = { model = ns .. ":block/example_block_lit" },
  },
})
registry.asset(
  "models/block/example_block",
  { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/iron_block" } }
)
registry.asset(
  "models/block/example_block_lit",
  { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/sea_lantern" } }
)
registry.asset("items/example_block", { model = { type = "minecraft:model", model = ns .. ":block/example_block" } })
registry.data("loot_table/blocks/example_block", {
  type = "minecraft:block",
  pools = {
    {
      condition = { type = "minecraft:survives_explosion" },
      entries = { { type = "minecraft:item", name = ns .. ":example_block" } },
      rolls = 1,
    },
  },
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
-- A staged block: an enum state property (`stage`) of three values, random
-- ticks on every stage (`random_ticks` names the property and the values
-- that tick), a sculk template with a little light and the catalyst's
-- sounds, a model per stage from three vanilla sculk textures, a hoe tag
-- (a hoe mines it, as sculk is mined) and a recipe. It grows and breeds in
-- scripts/server/example/nest.lua.
local STAGES = { "dormant", "growing", "mature" }
registry.block("example_nest", {
  template = "minecraft:sculk",
  properties = {
    hardness = 1.5,
    light = 2,
    sounds = "minecraft:sculk_catalyst",
    random_ticks = { property = "stage", values = STAGES },
  },
  state_properties = { stage = { type = "enum", values = STAGES } },
  default_state = { stage = "dormant" },
  item = true,
  components = { ["minecraft:max_stack_size"] = 16, ["minecraft:rarity"] = "uncommon" },
})
registry.asset("blockstates/example_nest", {
  variants = {
    ["stage=dormant"] = { model = ns .. ":block/example_nest_dormant" },
    ["stage=growing"] = { model = ns .. ":block/example_nest_growing" },
    ["stage=mature"] = { model = ns .. ":block/example_nest_mature" },
  },
})
registry.asset(
  "models/block/example_nest_dormant",
  { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/sculk" } }
)
registry.asset(
  "models/block/example_nest_growing",
  { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/sculk_catalyst_side" } }
)
registry.asset(
  "models/block/example_nest_mature",
  { parent = "minecraft:block/cube_all", textures = { all = "minecraft:block/sculk_catalyst_top_bloom" } }
)
registry.asset(
  "items/example_nest",
  { model = { type = "minecraft:model", model = ns .. ":block/example_nest_dormant" } }
)
registry.data("loot_table/blocks/example_nest", {
  type = "minecraft:block",
  pools = {
    {
      condition = { type = "minecraft:survives_explosion" },
      entries = { { type = "minecraft:item", name = ns .. ":example_nest" } },
      rolls = 1,
    },
  },
  random_sequence = ns .. ":blocks/example_nest",
})
registry.data("minecraft:tags/block/mineable/hoe", { values = { ns .. ":example_nest" } })
registry.data("recipe/example_nest", {
  type = "minecraft:crafting_shaped",
  category = "misc",
  pattern = { "WSW", "S S", "WSW" },
  key = { W = "minecraft:wheat", S = "minecraft:sculk" },
  result = { id = ns .. ":example_nest" },
})

registry.lang("en_us", {
  ["block.example_mod.example_block"] = "Example Lamp",
  ["block.example_mod.example_nest"] = "Example Nest",
})

return nil
