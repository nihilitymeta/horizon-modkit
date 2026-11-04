# Blocks

A block is declared in `scripts/registry.lua` (a template, the properties that differ, state properties of its
own, an item, the blockstate and models for its look) and gets a block class in a script. Examples:
[scripts/example/block.lua](../../examples/example_mod/scripts/example/block.lua) (a lamp with a boolean state)
and [scripts/example/nest.lua](../../examples/example_mod/scripts/example/nest.lua) (a staged block that breeds),
declared in [scripts/registry.lua](../../examples/example_mod/scripts/registry.lua). Reference:
[api.md, Blocks](../api.md#blocks-mblockname).

```lua
local Lamp = M:block("example_block")

-- Every placed block of this kind gets a block entity: saved data of its own,
-- kept with the chunk, and a tick every server tick when `ticks`.
Lamp:block_entity { ticks = true, data = { lit_ticks = 0 } }

-- A right click lights it; the click is eaten, so the held item does nothing.
-- The game tries the main hand and then the off hand, and this runs for
-- each, so it does one thing that is the same done twice (a toggle would
-- flip back).
function Lamp:on_use(block, player, held)
  if block.lit ~= "true" then
    block:set("lit", "true")
    horizon.log(("EXAMPLE block lit by %s"):format(player.name))
  end
  block:cancel()
end

-- Every server tick of a placed block, with block.data: count the lit ticks
-- and go dark after 100 (five seconds). Keep this light: it runs for every
-- placed block, every tick.
function Lamp:on_block_entity_tick(block)
  local data = block.data
  if not data or block.lit ~= "true" then return end
  data.lit_ticks = data.lit_ticks + 1
  if data.lit_ticks >= 100 then
    data.lit_ticks = 0
    block:set("lit", "false")
    horizon.log("EXAMPLE block dimmed after 100 ticks of light")
  end
end
```

**`block`** is the block at that moment: `x`, `y`, `z`, `id`, its state properties as fields (strings, as the
state spells them: `block.lit == "true"`), `block.data` (the block entity's saved table, written back after the
callback), and `block:set(key, value)`, `block:cancel()`, `block:replace(id, props)`, `block:drop(id, count)`,
`block:summon(kind, dx, dy, dz)`, `block:above()`, `block:light()`.

**The ticks.** `on_random_tick` runs when the block declares `random_ticks`; `block:schedule_tick(delay)` there
or in `on_tick` asks for a scheduled tick, which `on_tick` gets. Both ticks have no world at hand beyond
`block:set` and `block:handled()` (skip the template's own tick). `on_block_entity_tick` runs every server tick
of a block with a block entity and has the world: the nest breeds a mob from it.

**A staged block.** An enum state (`stage`) with `random_ticks` naming the property and the values that tick; the
nest grows on its random ticks, bone meal moves it a stage (the click runs per hand, so it reads the stage first),
a mature one charges in its block entity and summons into the air over it, and a spent one replaces itself:

```lua
-- A random tick (the block declares `random_ticks` for every stage): a
-- quarter of them grow it a stage. block:handled() keeps the sculk
-- template's own random tick away, in every stage.
function Nest:on_random_tick(block)
  local next_stage = NEXT_STAGE[block.stage]
  if next_stage and math.random() < 0.25 then
    block:set("stage", next_stage)
    horizon.log(("EXAMPLE nest grew to %s"):format(next_stage))
  end
  block:handled()
end
```

```lua
function Nest:on_block_entity_tick(block)
  local data = block.data
  if not data or block.stage ~= "mature" then return end
  data.charge = data.charge + 1
  if data.charge < BREED_TICKS or block:above() ~= "minecraft:air" then return end
  block:summon("example_mod:example_mob", 0, 1, 1)
  data.charge = 0
  data.bred = data.bred + 1
  horizon.log(("EXAMPLE nest bred an example mob (%d so far)"):format(data.bred))
  if data.bred >= cfg.nest_breeds then
    local l = block:light()
    block:broadcast(("the nest at %d %d %d is spent after %d example mob(s) (light %d/%d)"):format(block.x, block.y, block.z, data.bred, l.block, l.sky))
    block:drop("minecraft:wheat", 2)
    block:replace("minecraft:sculk")
    horizon.log(("EXAMPLE nest spent after %d"):format(data.bred))
  end
end
```

**Placed, broken, dropped.** `on_place(block, player, item)`, `on_break(block, player)` (return true to keep it:
the nest refuses a bare hand while mature, by `player.held`), `on_drops(block, drops, source)` (change the loot
list in place; `source.player`, `source.tool`, `source.explosion`). The block is gone when its loot drops, so
`block.stage` there comes from the state the engine names: the nest drops wheat instead of itself once grown.

**Declaring one.** A template, `properties` (`hardness`, `light`, `sounds`, `random_ticks`), `state_properties`
of your own with a `default_state`, `item = true`, then `blockstates/<name>` (a model per state),
`models/block/<name>` and `items/<name>` as tables, loot (`loot_table/blocks/<name>`) and a `mineable` tag.
The lamp and the nest are two worked ones.

See it in game: `/example lamp`, place it, right-click it, wait five seconds, break it; `/example nest`, place
it, bone meal it twice, wait twenty seconds, break it with a hoe.
