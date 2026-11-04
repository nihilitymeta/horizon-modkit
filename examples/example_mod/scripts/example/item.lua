-- Items: a class per item id with its callbacks (guide: docs/guides/items.md;
-- reference: docs/api.md, "Item classes"). The items are declared in
-- scripts/registry.lua. `item` is the stack in hand ({id, count, damage,
-- plain}, with item:take(n) and item:give(n)), `player` the player acting.
-- See it in game: /example feather, then right-click in the air (a hop,
-- sparks), on a block (what it is), hit a mob with it (slowed); /give @s
-- example_mod:example_snack and eat it (fast, then an effect).
local modkit = require("@modkit")
local M = require("@example/mod")

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

-- A blow at a mob while holding it, before the damage: `target` has id,
-- kind and position. The blow still lands (return true and it would not).
function Feather:on_hit(item, player, target)
  modkit.effect(target.id, "minecraft:slowness", 60, 1)
  horizon.log(("EXAMPLE item hit a %s"):format(target.kind))
end

-- After a blow with it landed.
function Feather:on_hurt_enemy(item, player, target)
  player:action_bar(("the feather struck a %s"):format(target.kind))
end

-- Taken out of a crafting grid, or thrown.
function Feather:on_crafted(item, player, recipe)
  player:tell(("you made %d feather(s) (%s)"):format(item.count, recipe))
end
function Feather:on_dropped(item, player, count)
  horizon.log(("EXAMPLE item dropped: %d by %s"):format(count, player.name))
end

local Snack = M:item("example_snack")

-- Eating starts: return a number of ticks to eat faster or slower than the
-- template does, true to stop the use.
function Snack:on_use_start(item, player, hand, duration)
  return 10
end

-- Eaten: an effect of this mod's own (scripts/registry.lua). Return an item
-- id (and a count) for what stays in the hand, as a bowl does; nothing here.
function Snack:on_finished(item, player)
  player:effect("example_mod:example_effect", 200)
  horizon.log(("EXAMPLE snack eaten by %s"):format(player.name))
end

return Feather
