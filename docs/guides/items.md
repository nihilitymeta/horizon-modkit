# Items

You declare an item once, in `scripts/registry.lua` or a module it requires, as a vanilla template and what differs
from it. Its behaviour lives in an item class in a script, with one callback for each thing a player does with it.

The examples on this page come from the example mod:

- [scripts/server/example/item.lua](../../examples/example_mod/scripts/server/example/item.lua): a feather and a snack
- [scripts/server/example/lure.lua](../../examples/example_mod/scripts/server/example/lure.lua): an item that summons and converts
  mobs
- [scripts/registry/items.lua](../../examples/example_mod/scripts/registry/items.lua): the declarations

The reference is [Item classes](../api.md#item-classes).

## A feather

The feather lifts the player who uses it, and names the block it is used on:

```lua
local Feather = M:item("example_item")

-- A right click in the air (or on a block that let it through): an effect on
-- the player, a sound and particles where they stand. Return true and the
-- click is taken: nothing else acts on it.
function Feather:on_use(item, player)
  local p = player.position
  player:effect("minecraft:levitation", 20, 1)
  modkit.sound("minecraft:entity.chicken.ambient", p.x, p.y, p.z, 1.0, 1.4)
  modkit.particles("minecraft:cloud", p.x, p.y + 0.5, p.z, 10, 0.4, 0.02)
  horizon.log(("EXAMPLE item used by %s"):format(player.name))
  return true
end

-- A right click on a block: `block` has x, y, z and id, `face` the side hit.
function Feather:on_use_on(item, player, block, face)
  player:action_bar(("%s at %d %d %d"):format(block.id, block.x, block.y, block.z))
  horizon.log(("EXAMPLE item used on %s"):format(block.id))
  return true
end
```

## The callbacks

| Callback | When it runs |
|---|---|
| `on_use` | a right click in the air |
| `on_use_on` | a right click on a block |
| `on_hit` | a blow, before the damage. Return true to cancel the blow |
| `on_hurt_enemy` | after a blow has landed |
| `on_crafted` | a player takes the item from a crafting grid |
| `on_dropped` | a player throws the item |
| `on_use_start` | eating, drinking or drawing starts. Return a number of ticks to change how long it takes |
| `on_finished` | the item is eaten or drunk. Return an item id for what stays in the hand |
| `on_tick` | every tick the item sits in an inventory. Keep it light |

`item` is the stack in hand: `{id, count, damage, plain}`, with `item:take(n)` and `item:give(n)` on the player's
inventory. `player` is the acting player, with `player:effect`, `player:tell`, `player:action_bar`, `player:give` and
the rest ([players and events](players-and-events.md)). Each hook wakes one handler for every item, which keeps the
stacks with its own id; `on_hit` reads the hand from the acting player's selected slot.

## An item that acts on the world

The lure is a bone by template. Its `on_use_on` summons an example mob on the clicked face. `horizon.summon` returns
the new mob's id, so the mob gets an effect at once. Then the callback uses up one lure and takes the click:

```lua
function Lure:on_use_on(item, player, block, face)
  local x, y, z = block.x + face.x + 0.5, block.y + face.y, block.z + face.z + 0.5
  local id = horizon.summon(player.dimension, "example_mod:example_mob", x, y, z)
  if id then modkit.effect(id, "minecraft:slowness", 60, 2) end
  modkit.sound("minecraft:entity.zombie.infect", x, y, z, 1.0, 0.6)
  modkit.particles("minecraft:crimson_spore", x, y + 1, z, 40, 0.6, 0.02)
  item:take(1)
  horizon.log(("EXAMPLE lure used on %s by %s"):format(block.id, player.name))
  return true
end
```

The lure's `on_hit` turns a zombie into an example mob, and cancels the blow.

## Vanilla items

`M:item("minecraft:stick")` gives every stick your callbacks.

## Declaring an item

```lua
registry.item("example_item", { template = "minecraft:feather", max_stack_size = 16, rarity = "uncommon" })
```

Then give it a look: `items/<name>` and `models/item/<name>` under `assets/`, written as tables with `registry.asset`,
and a name with `registry.lang("en_us", { ["item.<id>.<name>"] = "..." })`. A sword gets its damage through
`components`, as the engine's [mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md) describes. The
[ids reference](../reference/ids.md#item-templates) lists templates that are known to work.

## See it in the game

- `/example feather`: right-click in the air, right-click a block, then hit a mob with the feather.
- `/example lure`: right-click the ground, then hit a zombie.
