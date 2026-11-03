# Items

An item is declared once, in `scripts/registry.lua`, as a vanilla template and what differs; its behaviour is
an item class in a script, with a callback per thing a player does with it. Example:
[scripts/example/item.lua](../../examples/example_mod/scripts/example/item.lua), its declaration in
[scripts/registry.lua](../../examples/example_mod/scripts/registry.lua). Reference: [api.md, Items](../api.md#items-mitemname).

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

**The callbacks.** `on_use` (a right click in the air), `on_use_on` (on a block), `on_hit` (a blow, before the
damage; return true and it does nothing), `on_hurt_enemy` (after it landed), `on_crafted`, `on_dropped`,
`on_use_start` (eating, drinking, drawing starts; return a number of ticks to change how long), `on_finished`
(eaten or drunk; return an item id for what stays in the hand), `on_tick` (every tick it sits in an inventory:
keep it light).

**`item`** is the stack in hand, `{id, count, damage, plain}`, with `item:take(n)` and `item:give(n)` on the
player's inventory. **`player`** is the player acting, with `player:effect`, `player:tell`, `player:action_bar`,
`player:give` and the rest ([players and events](players-and-events.md)).

**Vanilla items too.** `M:item("minecraft:stick")` gives a stick callbacks; the parasite mod's lure is a bone by
template with an `on_use_on` and an `on_hit`.

**Declaring one.** `registry.item("example_item", { template = "minecraft:feather", max_stack_size = 16, rarity = "uncommon" })`,
then its look (`items/<name>` and `models/item/<name>` under assets, written as tables with `registry.asset`) and
a name in the lang file. A sword gets its damage through `components` (the engine's
[mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md)). Templates known to work:
[reference/ids.md](../reference/ids.md#item-templates).

See it in game: `/example feather`, right-click in the air, on a block, hit a mob with it.
