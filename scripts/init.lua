-- Horizon Modkit: mods that depend on this one `require("@modkit")` and get
-- the library (scripts/modkit.lua). What runs here is the modkit's own: the
-- inspect stick (scripts/registry.lua).
local modkit = require("@modkit")
horizon.log("modkit " .. modkit.VERSION .. " ready")

-- The inspect stick: a right-click on a block or an entity opens the inspect
-- windows on it instead of anything else the click would do. The game says
-- whether the click is the stick's (creative, permission 2 or more); if not,
-- the stick is any stick. The game turns the pages and sends the messages.
local STICK = "horizon_modkit:inspect_stick"
-- The game asks once per hand. The click the stick took this tick, by
-- player: the off hand's turn of it is cancelled too, so an item there does
-- nothing either.
local took = {}
local function inspect(player, held, key, what)
  local last = took[player.uuid]
  if held and held.item == STICK and horizon.dev.inspect(player, what) then
    took[player.uuid] = { tick = horizon.ticks(), key = key }
    return true
  end
  return last ~= nil and last.tick == horizon.ticks() and last.key == key
end
horizon.on("right_click_block", function(x, y, z, block, face, player, held)
  if inspect(player, held, x .. " " .. y .. " " .. z, { x = x, y = y, z = z, face = face }) then
    horizon.cancel()
  end
end)
horizon.on("entity_interact", function(dimension, entity, player, held)
  if inspect(player, held, entity.id, entity.id) then
    horizon.cancel()
  end
end)
