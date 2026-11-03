-- The players: callbacks on what every player does, as one class per mod.
--
--   local Players = M:players()
--   function Players:on_join(player) end                 -- joined the game
--   function Players:on_leave(player) end                -- left it, by any path
--   function Players:on_respawn(player) end              -- respawned after a death
--   function Players:on_death(player, cause) end         -- died; cause is the death message's key or nil
--   function Players:on_break_block(player, block) end   -- breaking a block (block: x, y, z, id); return true to keep it
--   function Players:on_place_block(player, block, item) end
--   function Players:on_pickup(player, item, count) end  -- about to pick an item (an id) up; return true to leave it
--
-- `player` is the engine's table (`uuid`, `name`, `position`...).
local Players = {}

local CALLBACKS = {
  on_join = { "player_joined", function(e, player) e:on_join(player) end },
  on_leave = { "player_left", function(e, player) e:on_leave(player) end },
  on_respawn = { "player_respawned", function(e, player) e:on_respawn(player) end },
  on_death = { "player_died", function(e, player, cause) e:on_death(player, cause) end },
  on_break_block = { "block_broken", function(e, x, y, z, block, player)
    if e:on_break_block(player, { x = x, y = y, z = z, id = block }) == true then horizon.cancel() end
  end },
  on_place_block = { "block_placed", function(e, x, y, z, block, player, item)
    e:on_place_block(player, { x = x, y = y, z = z, id = block }, item)
  end },
  on_pickup = { "item_picked_up", function(e, player, item, count)
    if e:on_pickup(player, item, count) == true then horizon.cancel() end
  end },
}

Players.__index = Players
Players.__newindex = function(self, key, value)
  rawset(self, key, value)
  local cb = CALLBACKS[key]
  if cb and value ~= nil then self:_listen(key, cb[1], cb[2]) end
end

function Players.new(mod)
  return setmetatable({ mod = mod, _hooked = {} }, Players)
end

function Players:_listen(name, hook, adapt)
  if self._hooked[hook] then return end
  self._hooked[hook] = true
  local e = self
  horizon.on(hook, function(...)
    if e[name] then adapt(e, ...) end
  end)
end

return Players
