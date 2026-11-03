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
--   function Players:on_tick(player) end                 -- every server tick of every player: keep it light
--   function Players:on_hurt(player, hit) end            -- about to take damage: hit:set_amount(n), hit:cancel(); player is {id, kind}
--   function Players:on_fall(player, fall) end           -- about to land: fall.distance, fall:set_distance(n), fall:set_multiplier(n), fall:cancel()
--   function Players:on_knockback(player, hit) end       -- about to be pushed: hit.strength, hit:set_strength(n), hit:cancel()
--   function Players:on_command(player, line) end        -- typed a command; return true to stop it; player:reply(text) answers
--   function Players:on_chat(player, line) end           -- a chat line; return true to drop it, a string to send instead
--   function Players:on_change_dimension(player, from, to) end
--   function Players:on_sleep(player, x, y, z) end       -- entering a bed; return true to keep them out
--   function Players:on_exp(player, amount) end          -- about to gain experience from an orb; return a number to change it
--   function Players:on_open_menu(player, menu, pos) end -- opened a menu (menu its type, pos its block or nil)
--
-- `player` is the engine's table (`uuid`, `name`, `position`...) with the
-- player's methods (modkit.player: `player:give`, `player:effect`...).
local Player = require("@modkit/player")
local wrap = Player.wrap

local Players = {}

local CALLBACKS = {
  on_join = { "player_joined", function(e, player) e:on_join(wrap(player)) end },
  on_leave = { "player_left", function(e, player) e:on_leave(wrap(player)) end },
  on_respawn = { "player_respawned", function(e, player) e:on_respawn(wrap(player)) end },
  on_death = { "player_died", function(e, player, cause) e:on_death(wrap(player), cause) end },
  on_break_block = { "block_broken", function(e, x, y, z, block, player)
    if e:on_break_block(wrap(player), { x = x, y = y, z = z, id = block }) == true then horizon.cancel() end
  end },
  on_place_block = { "block_placed", function(e, x, y, z, block, player, item)
    e:on_place_block(wrap(player), { x = x, y = y, z = z, id = block }, item)
  end },
  on_pickup = { "item_picked_up", function(e, player, item, count)
    if e:on_pickup(wrap(player), item, count) == true then horizon.cancel() end
  end },
  on_tick = { "player_tick", function(e, player) e:on_tick(wrap(player)) end },
  on_hurt = { "player_hurt", function(e, player, damage_type, causing, direct, amount)
    e:on_hurt(player, {
      damage_type = damage_type, causing = causing, direct = direct, amount = amount,
      set_amount = function(self, n) self.amount = n; horizon.set_amount(n) end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end },
  on_fall = { "player_fall", function(e, player, distance, multiplier)
    e:on_fall(player, {
      distance = distance, multiplier = multiplier,
      set_distance = function(self, n) self.distance = n; horizon.set_distance(n) end,
      set_multiplier = function(self, n) self.multiplier = n; horizon.set_multiplier(n) end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end },
  on_knockback = { "player_knockback", function(e, player, damage_type, causing, direct, strength, x, z)
    e:on_knockback(player, {
      damage_type = damage_type, causing = causing, direct = direct, strength = strength, x = x, z = z,
      set_strength = function(self, n) self.strength = n; horizon.set_strength(n) end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end },
  on_chat = { "player_chat", function(e, player, line)
    local r = e:on_chat(player, line)
    if r == true then horizon.cancel() elseif type(r) == "string" then horizon.set_line(r) end
  end },
  on_command = { "player_command", function(e, player, line)
    player = wrap(player)
    player.reply = function(_, text) horizon.reply(text) end
    if e:on_command(player, line) == true then horizon.cancel() end
  end },
  on_change_dimension = { "player_changed_dimension", function(e, player, from, to) e:on_change_dimension(wrap(player), from, to) end },
  on_sleep = { "player_bed_enter", function(e, player, x, y, z)
    if e:on_sleep(wrap(player), x, y, z) == true then horizon.cancel() end
  end },
  on_exp = { "player_exp_change", function(e, player, amount)
    local n = e:on_exp(wrap(player), amount)
    if type(n) == "number" then horizon.set_amount(n) end
  end },
  on_open_menu = { "player_container_open", function(e, player, menu, pos) e:on_open_menu(wrap(player), menu, pos) end },
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
