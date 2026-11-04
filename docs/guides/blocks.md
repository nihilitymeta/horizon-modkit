# Blocks

A block has two parts. You declare it in `scripts/registry.lua`, and you give it behaviour with a block class in a
script.

The examples on this page come from the example mod:

- [scripts/example/block.lua](../../examples/example_mod/scripts/example/block.lua): a lamp with a boolean state
- [scripts/example/nest.lua](../../examples/example_mod/scripts/example/nest.lua): a block with stages that breeds
  mobs
- [scripts/registry.lua](../../examples/example_mod/scripts/registry.lua): the declarations of both

The reference is [Block classes](../api.md#block-classes).

## A lamp

This block lights up when a player right-clicks it, and goes dark after five seconds:

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

## The block table

The `block` table describes the block at that moment. It has these fields:

- `x`, `y`, `z` and `id`
- each state property, as a string spelled as the state spells it: `block.lit == "true"`
- `block.data`, the block entity's saved table, written back after the callback

Its methods include `block:set(key, value)`, `block:cancel()`, `block:replace(id, props)`, `block:drop(id, count)`,
`block:summon(kind, dx, dy, dz)`, `block:above()` and `block:light()`. [The block](../api.md#the-block) lists them
all, with where each one works.

## Ticks

A block can have three kinds of tick:

- `on_random_tick` runs when the block declares `random_ticks` in its data.
- `on_tick` runs when a scheduled tick is due. Ask for one with `block:schedule_tick(delay)` in either tick.
- `on_block_entity_tick` runs every server tick for a block with a ticking block entity.

The random and scheduled ticks can't reach the rest of the world. They can change the block with `block:set`, and
skip the template's own tick with `block:handled()`. The block entity tick can reach the world: the nest uses it to
breed a mob.

## A block with stages

The nest has an enum state property, `stage`, and declares `random_ticks` for it. It grows on its random ticks:

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

Bone meal moves the nest on by one stage. Because the click runs once for each hand, the callback reads the stage
first. A mature nest charges up in its block entity and summons a mob into the air over it. After a set number of
mobs, the nest is spent and replaces itself with sculk:

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

## Placing, breaking and loot

- `on_place(block, player, item)` runs after a player places the block.
- `on_break(block, player)` runs when a player breaks it. Return true to keep the block. The nest uses
  `player.held` to refuse a bare hand while it is mature.
- `on_drops(block, drops, source)` runs before the loot drops. Change the `drops` list in place. `source` has
  `player`, `tool` and `explosion`.

The block is already gone when its loot drops, so `block.stage` comes from the state that the game reports. The nest
uses it to drop wheat instead of itself once it has grown.

## Declaring a block

A block's declaration names:

- a template
- the `properties` that differ from it, such as `hardness`, `light`, `sounds` and `random_ticks`
- `state_properties` of its own, with a `default_state`
- `item = true`, for an item that places it

Its look and loot are written as tables too: `blockstates/<name>` (a model for each state), `models/block/<name>`,
`items/<name>`, a loot table at `loot_table/blocks/<name>`, and a `mineable` tag. The lamp and the nest in
[scripts/registry.lua](../../examples/example_mod/scripts/registry.lua) are two complete declarations.

## See it in the game

- `/example lamp`: place the lamp, right-click it, wait five seconds, then break it.
- `/example nest`: place the nest, use bone meal on it twice, wait twenty seconds, then break it with a hoe.
