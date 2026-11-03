# Blocks

A block is declared in `scripts/registry.lua` (a template, the properties that differ, state properties of its
own, an item, the blockstate and models for its look) and gets a block class in a script. Example:
[scripts/example/block.lua](../../examples/example_mod/scripts/example/block.lua), declared in
[scripts/registry.lua](../../examples/example_mod/scripts/registry.lua). Reference: [api.md, Blocks](../api.md#blocks-mblockname).

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
of a block with a block entity and has the world: a parasite hive breeds a mob from it.

**Placed, broken, dropped.** `on_place(block, player, item)`, `on_break(block, player)` (return true to keep it),
`on_drops(block, drops, source)` (change the loot list in place; `source.player`, `source.tool`,
`source.explosion`).

**Declaring one.** A template, `properties` (`hardness`, `light`, `sounds`, `random_ticks`), `state_properties`
of your own with a `default_state`, `item = true`, then `blockstates/<name>` (a model per state),
`models/block/<name>` and `items/<name>` as tables, loot (`loot_table/blocks/<name>`) and a `mineable` tag.
The example lamp and the parasite hive are two worked ones.

See it in game: `/example lamp`, place it, right-click it, wait five seconds, break it.
