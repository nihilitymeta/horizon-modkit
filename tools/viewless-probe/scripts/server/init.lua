-- Guards the viewless-mob rule (docs/api.md, "Entity classes"): the view
-- callbacks (`E:on_tick`, `E:on_interact`) are skipped when the mob has no
-- live view, instead of running with a `mob` whose fields read nil.
-- Headless (`tools/check.sh`) no hook runs, and `horizon.mob` only reads
-- inside one, so the probe stubs the engine's viewless answer (nil for a
-- dead or gone mob) and drives the same adapter functions the engine's hooks
-- call (kept as `E._adapter` when each callback was defined), not the
-- callbacks directly.
local modkit = require("@modkit")
local M = modkit.mod("viewless_probe")

local E = M:entity("minecraft:pig")
local ran = {}
function E:on_tick(mob)
  ran.tick = true
end
function E:on_interact(mob, player, held)
  ran.interact = true
end

local real_mob = horizon.mob
horizon.mob = function(id)
  return nil
end
E._adapter.on_tick(E, { entity = 424242, kind = "minecraft:pig", dimension = "minecraft:overworld" })
assert(ran.tick == nil, "E:on_tick ran for a mob with no live view")
E._adapter.on_interact(E, { entity = 424242, kind = "minecraft:pig", stack = nil })
assert(ran.interact == nil, "E:on_interact ran for a mob with no live view")
horizon.mob = real_mob
horizon.log("VIEWLESS probe: view callbacks skipped with no live view")
