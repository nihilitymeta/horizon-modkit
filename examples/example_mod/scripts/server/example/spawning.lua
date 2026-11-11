-- Spawning (guide: docs/guides/spawning.md). The egg and the natural spawns
-- are data in scripts/registry.lua; this is what a script does: a mob made
-- at a point (horizon.summon answers its id, so it can be acted on at once)
-- and the callback when one of the kind appears, naturally or not.
-- See it in game: /example spawn 2; "EXAMPLE mob spawned" in the log, also
-- when one spawns on its own at night.
local modkit = require("@modkit")
local M = require("@example/mod")

local Mob = M:entity("example_mob")

-- A mob of this type spawned: ev.x, ev.y, ev.z, ev.dimension, ev.natural.
function Mob:on_spawned(ev)
  horizon.log(("EXAMPLE mob spawned at %.0f %.0f %.0f%s"):format(ev.x, ev.y, ev.z, ev.natural and " on its own" or ""))
end

-- Mobs made beside the player. A command has no world at hand, so the
-- summons run next tick, from a timer.
M:command("example spawn [count:integer]", 2, function(player, args)
  local count, p, dimension = args.count or 1, player.position, player.dimension
  horizon.after(1, function()
    for i = 1, count do
      local id = horizon.summon(dimension, "example_mod:example_mob", p.x + i, p.y, p.z)
      if id then modkit.effect(id, "minecraft:glowing", 100) end
    end
  end)
  horizon.feedback(("%d example mob(s) coming"):format(count))
end)

return M
