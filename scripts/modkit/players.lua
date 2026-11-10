-- The players: callbacks on what every player does, as one class per mod.
--
--   local Players = M:players()
--   function Players:on_join(player) end                 -- joined the game
--   function Players:on_leave(player) end                -- left it, by any path
--   function Players:on_respawn(player) end              -- respawned after a death
--   function Players:on_death(uuid, cause) end           -- died; cause is the death message's key or nil
--   function Players:on_break_block(player, block) end   -- breaking a block (block: x, y, z, id); return true to keep it
--   function Players:on_place_block(player, block, item) end
--   function Players:on_pickup(player, item, count) end  -- about to pick an item (an id) up; return true to leave it
--   function Players:on_tick(player) end                 -- every server tick of every player: keep it light
--   function Players:on_hurt(player, hit) end            -- about to take damage: hit.amount = n, hit:cancel(); player is {id, kind}
--   function Players:on_fall(player, fall) end           -- about to land: fall.distance = n, fall:cancel()
--   function Players:on_knockback(player, hit) end       -- about to be pushed: hit.strength = n, hit:cancel()
--   function Players:on_command(player, line) end        -- typed a command; return true to stop it; player:reply(text) answers
--   function Players:on_chat(player, line) end           -- a chat line; return true to drop it, a string to answer the sender
--   function Players:on_change_dimension(player, from, to) end
--   function Players:on_sleep(player, x, y, z) end       -- entering a bed; return true to keep them out
--   function Players:on_exp(player, amount) end          -- about to gain experience from an orb; return a number to change it
--   function Players:on_open_menu(player, menu, pos) end -- opened a menu (menu its type, pos its block or nil)
--
-- `player` is the engine's table (`uuid`, `name`, `position`...) with the
-- player's methods (modkit.player: `player:give`, `player:effect`...), except
-- in `on_death` (a uuid: the dying player is already gone) and `on_chat`
-- (only `uuid` and `name`). The hurt, fall and knockback callbacks run in the
-- middle of the event: `player` is only `{id, kind}` there.
local Player = require("@modkit/player")
local wrap = Player.wrap

local Players = {}

-- The acting player: the first player of the world. The break, place and
-- tick events hand out no player table.
local function acting()
  return wrap(horizon.players()[1])
end

-- The player a uuid names, or a bare uuid table when the server does not
-- hold them. `player:` methods that take a uuid still reach them.
local function named(uuid)
  return wrap(horizon.player(uuid) or { uuid = uuid })
end

local KIND_PLAYER = "minecraft:player"

local CALLBACKS = {
  on_join = { "player_logged_in", function(e, event) e:on_join(wrap(event.player)) end },
  on_leave = { "player_logged_out", function(e, event) e:on_leave(wrap(event.player)) end },
  on_respawn = { "player_respawned", function(e, event) e:on_respawn(wrap(event.player)) end },
  on_death = { "player_died", function(e, event) e:on_death(event.player, event.cause) end },
  on_break_block = { "destroy_block", function(e, event)
    if e:on_break_block(acting(), { x = event.pos.x, y = event.pos.y, z = event.pos.z, id = event.state }) == true then horizon.cancel() end
  end },
  on_place_block = { "place_block", function(e, event)
    e:on_place_block(acting(), { x = event.pos.x, y = event.pos.y, z = event.pos.z, id = event.state }, event.stack)
  end },
  on_pickup = { "item_picked_up", function(e, event)
    if e:on_pickup(named(event.player), event.item, event.count) == true then horizon.cancel() end
  end },
  on_tick = { "player_tick", function(e, event) e:on_tick(acting()) end },
  on_hurt = { "living_incoming_damage", function(e, event)
    e:on_hurt({ id = event.entity, kind = event.kind }, {
      damage_type = event.damage_type, causing = event.causing, direct = event.direct, amount = event.amount,
      set_amount = function(self, n) self.amount = n; event.amount = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end, KIND_PLAYER },
  on_fall = { "living_fall", function(e, event)
    e:on_fall({ id = event.entity, kind = event.kind }, {
      distance = event.distance, multiplier = event.multiplier,
      set_distance = function(self, n) self.distance = n; event.distance = n end,
      set_multiplier = function(self, n) self.multiplier = n; event.multiplier = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end, KIND_PLAYER },
  on_knockback = { "living_knockback", function(e, event)
    local hit = {
      damage_type = event.damage_type, causing = event.causing, direct = event.direct,
      strength = event.strength, x = event.x, z = event.z,
      set_strength = function(self, n) self.strength = n; event.strength = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    }
    e:on_knockback({ id = event.entity, kind = event.kind }, hit)
    event.x, event.z = hit.x, hit.z
  end, KIND_PLAYER },
  on_chat = { "player_chat", function(e, event)
    local r = e:on_chat({ uuid = event.player, name = event.name }, event.message)
    if r == true then horizon.cancel() elseif type(r) == "string" then event.replies = { r } end
  end },
  on_command = { "player_command", function(e, event)
    local player = wrap(event.player)
    player.reply = function(_, text) event.replies[#event.replies + 1] = text end
    if e:on_command(player, event.command) == true then horizon.cancel() end
  end },
  on_change_dimension = { "player_changed_dimension", function(e, event) e:on_change_dimension(wrap(event.player), event.from, event.to) end },
  on_sleep = { "player_bed_enter", function(e, event)
    if e:on_sleep(wrap(event.player), event.pos.x, event.pos.y, event.pos.z) == true then horizon.cancel() end
  end },
  on_exp = { "player_exp_change", function(e, event)
    local n = e:on_exp(wrap(event.player), event.amount)
    if type(n) == "number" then event.amount = n end
  end },
  on_open_menu = { "player_container_open", function(e, event) e:on_open_menu(wrap(event.player), event.menu, event.pos) end },
}

Players.__index = Players
Players.__newindex = function(self, key, value)
  rawset(self, key, value)
  local cb = CALLBACKS[key]
  if cb and value ~= nil then self:_listen(key, cb[1], cb[2], cb[3]) end
end

function Players.new(mod)
  return setmetatable({ mod = mod, _hooked = {} }, Players)
end

function Players:_listen(name, hook, adapt, kind)
  if self._hooked[hook] then return end
  self._hooked[hook] = true
  local e = self
  horizon.on(hook, function(event)
    if e[name] then adapt(e, event) end
  end, kind)
end

return Players
