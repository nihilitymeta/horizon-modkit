-- Horizon Modkit: mods that depend on this one `require("@modkit")` and get
-- the library (scripts/modkit.lua). What runs here is the modkit's own: the
-- inspect stick (scripts/registry.lua).
local modkit = require("@modkit")
horizon.log("modkit " .. modkit.VERSION .. " ready")

-- The inspect stick: a right-click on a block or an entity opens the inspect
-- windows on it instead of anything else the click would do. The engine says
-- whether the click is the stick's (creative, permission 2 or more); if not,
-- the stick is any stick. The game turns the pages and sends the messages.
-- The click the stick took this tick, by player: the off hand's turn of it is
-- cancelled too, so an item there does nothing either. The native events name
-- no held stack, so every click is asked: `dev.inspect` answers false for
-- any click that is not the stick's.
local took = {}
local function inspect(player_uuid, key, what)
  local last = took[player_uuid]
  if horizon.dev.inspect(player_uuid, what) then
    took[player_uuid] = { tick = horizon.ticks(), key = key }
    return true
  end
  return last ~= nil and last.tick == horizon.ticks() and last.key == key
end
local function acting_uuid()
  local players = horizon.players()
  return players[1] ~= nil and players[1].uuid or nil
end
horizon.on("right_click_block", function(event)
  local uuid = acting_uuid()
  if uuid == nil then return end
  local pos = event.pos
  if inspect(uuid, pos.x .. " " .. pos.y .. " " .. pos.z, { x = pos.x, y = pos.y, z = pos.z, face = event.face }) then
    horizon.cancel()
  end
end)
horizon.on("interact_entity", function(event)
  local uuid = acting_uuid()
  if uuid == nil then return end
  if event.stack ~= nil then
    -- The tried hand holds something: ask, as the old hook's held test did.
    -- An empty hand's turn (the off hand's, after the main hand's click)
    -- only cancels when it is the same tick's: asking again would turn the
    -- stick's pages twice for one click.
    if inspect(uuid, event.entity, event.entity) then
      horizon.cancel()
    end
  else
    local last = took[uuid]
    if last ~= nil and last.tick == horizon.ticks() and last.key == event.entity then
      horizon.cancel()
    end
  end
end)
