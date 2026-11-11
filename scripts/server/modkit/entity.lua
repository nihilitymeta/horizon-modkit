-- An entity class: goals and lifecycle callbacks for one entity type, the
-- mod's own (declared in its data) or a vanilla kind.
--
--   local Crawler = M:entity("crawler")
--   Crawler:goals { {1, Hunt}, {5, modkit.goals.Wander()} }
--   Crawler:target_goals { ... }
--   Crawler.replace_goals = true               -- drop the vanilla goals first (a mod type with "goals": "template")
--   function Crawler:on_spawned(ev) end        -- ev: dimension, kind, x, y, z, natural
--   function Crawler:on_tick(mob) end          -- every server tick: the live view, host actions
--   function Crawler:on_ai_tick(mob, state) end -- every AI tick, as a goal of its own: steering actions
--   function Crawler:on_hurt(mob, hit) end     -- about to take damage: hit.amount = n, hit:cancel()
--   function Crawler:on_death(mob, cause) end  -- it died, by any cause: cause.damage_type, .causing, .player (a uuid, or nil)
--   function Crawler:on_interact(mob, player, held) end -- right-clicked; return true to take the click
--   function Crawler:on_fall(mob, fall) end     -- about to land: fall.distance = n, fall:cancel()
--   function Crawler:on_knockback(mob, hit) end -- about to be pushed: hit.strength = n, hit:cancel()
--   function Crawler:on_equip(mob, slot, from, to) end  -- an equipment slot changed (item tables or nil)
--   function Crawler:on_drops(mob, drops, source) end   -- its loot is about to drop: change `drops` ({id, count} entries) in place
--
-- A callback is wired to the game's hook for the class's kind the moment it
-- is defined, so a kind without one costs nothing each tick.
--
-- A callback with a host reads `mob.data`, the mob's saved table
-- (`horizon.entity_data`), fetched on first use: the view callbacks
-- (`on_tick`, `on_interact`), `on_death`, `on_equip` and `on_drops`. The
-- hostless callbacks (`on_hurt`, `on_fall`, `on_knockback`) and goals read
-- nil there. A callback that documents `mob` as the live view
-- (`on_tick`, `on_interact`) is skipped when `horizon.mob(id)` is nil (the
-- mob is dead or gone): there is nothing to hand it. The rest document `mob`
-- as id and kind only and keep running. The acting player of `on_interact`
-- is `horizon.acting_player()`, and `held` is the stack in the hand being
-- tried (main then off), or nil when that hand is empty.
local Goal = require("@modkit/goal")
local Mob = require("@modkit/mob")
local Player = require("@modkit/player")

local Entity = {}

-- The live view for the view callbacks (`on_tick`, `on_interact`), or nil
-- when the mob is dead or gone: those callbacks are skipped then, since
-- there is no mob to hand them. Every other entity callback documents `mob`
-- as id and kind only, so it keeps running without a view. The mid-event
-- hooks have no host, and a dead or gone mob has no view.
local function live(event)
  return horizon.mob(event.entity)
end

-- Which hook each callback listens to, and how the hook's one event table
-- becomes the callback's arguments.
local CALLBACKS = {
  on_spawned = { "mob_spawned", function(e, event)
    e:on_spawned({ dimension = event.dimension, kind = event.kind, x = event.pos.x, y = event.pos.y, z = event.pos.z, natural = event.natural })
  end },
  on_tick = { "entity_tick_post", function(e, event)
    local v = live(event)
    if v == nil then return end
    e:on_tick(Mob.host(v, event.dimension, nil))
  end },
  on_hurt = { "living_incoming_damage", function(e, event)
    local hit = {
      damage_type = event.damage_type, causing = event.causing, direct = event.direct, amount = event.amount,
      set_amount = function(self, n) self.amount = n; event.amount = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    }
    e:on_hurt(Mob.host({ id = event.entity, kind = event.kind }, nil, nil), hit)
  end },
  on_death = { "mob_died", function(e, event)
    e:on_death(Mob.host({ id = event.entity, kind = event.kind }, event.dimension, nil), {
      damage_type = event.damage_type, causing = event.causing, player = event.player,
    })
  end },
  on_interact = { "interact_entity", function(e, event)
    local v = live(event)
    if v == nil then return end
    local player = Player.wrap(horizon.acting_player())
    if player == nil then return end
    local stack = event.stack
    local held = stack ~= nil and { item = stack.id, count = stack.count, plain = stack.plain } or nil
    if e:on_interact(Mob.host(v, horizon.time().dimension, nil), player, held) == true then horizon.cancel() end
  end },
  on_fall = { "living_fall", function(e, event)
    e:on_fall(Mob.host({ id = event.entity, kind = event.kind }, nil, nil), {
      distance = event.distance, multiplier = event.multiplier,
      set_distance = function(self, n) self.distance = n; event.distance = n end,
      set_multiplier = function(self, n) self.multiplier = n; event.multiplier = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    })
  end },
  on_knockback = { "living_knockback", function(e, event)
    local hit = {
      damage_type = event.damage_type, causing = event.causing, direct = event.direct,
      strength = event.strength, x = event.x, z = event.z,
      set_strength = function(self, n) self.strength = n; event.strength = n end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    }
    e:on_knockback(Mob.host({ id = event.entity, kind = event.kind }, nil, nil), hit)
    event.x, event.z = hit.x, hit.z
  end },
  on_equip = { "living_equipment_change", function(e, event)
    e:on_equip(Mob.host({ id = event.entity, kind = event.kind }, horizon.time().dimension, nil), event.slot, event.from, event.to)
  end },
  on_drops = { "loot_drops", function(e, event)
    e:on_drops(Mob.host(event.entity, event.dimension, nil), event.drops, event)
  end },
}

Entity.__index = Entity
-- Defining a callback (`function E:on_tick(mob) ... end`) registers its hook
-- for this kind, once.
Entity.__newindex = function(self, key, value)
  rawset(self, key, value)
  local cb = CALLBACKS[key]
  if cb and value ~= nil then self:_listen(key, cb[1], cb[2]) end
end

function Entity.new(mod, id)
  local e = setmetatable({ mod = mod, id = id, goal_list = {}, target_list = {}, replace_goals = false, _hooked = {} }, Entity)
  horizon.on("mob_ai_register", function(event) e:_register(event.mob) end, id)
  return e
end

function Entity:_listen(name, hook, adapt)
  if self._hooked[hook] then return end
  self._hooked[hook] = true
  -- Kept for the headless guard test (tools/viewless-probe): the same
  -- function the engine's hook calls, driven there with a fake event.
  self._adapter = self._adapter or {}
  self._adapter[name] = adapt
  local e = self
  horizon.on(hook, function(...)
    if e[name] then adapt(e, ...) end
  end, self.id)
end

--- Adds goals that every mob of this type gets: `{ {priority, goal}, ... }`,
--- a lower priority first.
function Entity:goals(list: { { any } })
  for _, row in ipairs(list) do self.goal_list[#self.goal_list + 1] = row end
  return self
end

--- Adds goals to the mob's target selector: `{ {priority, goal}, ... }`.
function Entity:target_goals(list: { { any } })
  for _, row in ipairs(list) do self.target_list[#self.target_list + 1] = row end
  return self
end

local function short(id) return (id:gsub("^[^:]*:", "")) end

-- Called as a mob of this type sets its goals up (`mob_ai_register`).
function Entity:_register(mob)
  if self.replace_goals then
    horizon.clear_goals()
    horizon.clear_target_goals()
  end
  local base = short(self.id)
  -- One engine name per row: two goals named alike (two Wanders) would
  -- otherwise share one definition, since the game keeps the last by name.
  local taken = {}
  for i, row in ipairs(self.goal_list) do
    local name = base .. "." .. (row[2].def.name or ("goal" .. i))
    if taken[name] then name = name .. i end
    taken[name] = true
    horizon.add_goal(row[1], row[2]:register(name))
  end
  for i, row in ipairs(self.target_list) do
    horizon.add_target_goal(row[1], row[2]:register(base .. ".target" .. i))
  end
  if self.on_ai_tick then
    local entity = self
    if not rawget(self, "_tick_goal") then
      rawset(self, "_tick_goal", Goal.new {
        flags = {},
        every_tick = true,
        can_use = function() return true end,
        tick = function(state, mob) entity:on_ai_tick(mob, state) end,
      })
    end
    horizon.add_goal(99, self._tick_goal:register(base .. ".tick"))
  end
end

-- Nothing to install any more: each class listens for its own kind.
function Entity.install(mod) end

return Entity
