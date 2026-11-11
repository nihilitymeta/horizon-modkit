-- An item that summons on use and converts on a blow (guide:
-- docs/guides/items.md; reference: docs/api.md, "Item classes"). The lure is a bone
-- by template (scripts/registry.lua). Used on a block, an example mob climbs
-- out of the clicked face and one lure is spent; a zombie struck with it is
-- an example mob on the spot (removed, one summoned where it stood). Both
-- return true: the click, or the blow, is taken and nothing else happens.
-- See it in game: /example lure, right-click the ground, hit a zombie.
local modkit = require("@modkit")
local M = require("@example/mod")

local Lure = M:item("example_lure")

-- `face` is the side hit, as {x, y, z}: the mob appears one block out from
-- it. horizon.summon answers the new mob's id at once, so it gets an effect.
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

-- Before the blow lands: `target` has id, kind and position. A zombie is
-- taken out with no death and no loot, and an example mob stands in for it.
function Lure:on_hit(item, player, target)
  if target.kind ~= "minecraft:zombie" then return end
  horizon.remove_mob(player.dimension, target.id)
  horizon.summon(player.dimension, "example_mod:example_mob", target.position.x, target.position.y, target.position.z)
  item:take(1)
  horizon.broadcast(("%s turned a zombie with the lure"):format(player.name))
  horizon.log("EXAMPLE lure turned a zombie")
  return true
end

M:command("example lure [count:integer]", 2, function(player, args)
  local count = args.count or 1
  player:give("example_mod:example_lure", count)
  horizon.feedback(("%d lure(s) given: right-click the ground, or hit a zombie"):format(count))
end)

return Lure
