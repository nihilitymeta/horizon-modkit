-- Horizon Modkit: mods that depend on this one `require("@modkit")` and get
-- the library (scripts/modkit.lua). What runs here is the modkit's own: the
-- inspect stick (scripts/registry.lua).
local modkit = require("@modkit")
horizon.log("modkit " .. modkit.VERSION .. " ready")

-- The inspect stick: a right-click on a block or an entity opens the inspect
-- windows on it instead of anything else the click would do. The engine opens
-- the windows for any creative click (permission 2 or more) without looking
-- at the held item, so this file asks only when the click holds the stick (a
-- plain stick keeps its vanilla click). The game turns the pages and sends
-- the messages.
-- The click the stick took this tick, by player: the off hand's turn of it is
-- cancelled too, so an item there does nothing either. The native
-- `right_click_block` event names no held stack and no hand: the acting
-- player's `held` is the selected (main-hand) slot, so a stick in the off
-- hand alone never opens the windows on a block (docs/api.md, "The inspect
-- stick"). The tried hand's stack names the hand, so either hand's stick
-- opens them on an entity.
local STICK = "horizon_modkit:inspect_stick"
local took = {}
-- Takes the click when the stick took it: records this tick and key the first
-- time the engine answers true for a hand holding the stick, and cancels
-- without asking again when the other hand's turn of the same tick names the
-- same key.
local function inspect(player_uuid, key, what, is_stick)
  local last = took[player_uuid]
  if last ~= nil and last.tick == horizon.ticks() and last.key == key then
    return true
  end
  if is_stick and horizon.dev.inspect(player_uuid, what) then
    took[player_uuid] = { tick = horizon.ticks(), key = key }
    return true
  end
  return false
end
-- The acting player of the click, or nil where the hook names none: the
-- click is left alone then.
local function acting()
  return horizon.acting_player()
end
horizon.on("right_click_block", function(event)
  local player = acting()
  if player == nil then return end
  local uuid = player.uuid
  local pos = event.pos
  local held = player.held
  if inspect(uuid, pos.x .. " " .. pos.y .. " " .. pos.z, { x = pos.x, y = pos.y, z = pos.z, face = event.face }, held ~= nil and held.id == STICK) then
    horizon.cancel()
  end
end)
horizon.on("interact_entity", function(event)
  local player = acting()
  if player == nil then return end
  local uuid = player.uuid
  local stack = event.stack
  if stack == nil then
    -- An empty hand's turn (the off hand's, after the main hand's click):
    -- cancel only when it is the same tick's, without asking again (asking
    -- twice would turn the stick's pages twice for one click).
    local last = took[uuid]
    if last ~= nil and last.tick == horizon.ticks() and last.key == event.entity then
      horizon.cancel()
    end
  elseif stack.id == STICK then
    -- The tried hand holds the stick: ask, as the old hook's held test did.
    if inspect(uuid, event.entity, event.entity, true) then
      horizon.cancel()
    end
  end
end)
