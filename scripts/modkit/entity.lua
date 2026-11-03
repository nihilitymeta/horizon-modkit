-- An entity class: goals and lifecycle callbacks for one entity type, the
-- mod's own (declared in its data) or a vanilla kind.
--
--   local Crawler = M:entity("crawler")
--   Crawler:goals { {1, Hunt}, {5, modkit.goals.Wander()} }
--   Crawler:target_goals { ... }
--   Crawler.replace_goals = true               -- drop the vanilla goals first (a mod type with "goals": "template")
--   function Crawler:on_spawned(ev) end        -- ev: dimension, kind, x, y, z, natural
--   function Crawler:on_tick(mob) end          -- every server tick: mob.data, host actions
--   function Crawler:on_ai_tick(mob, state) end -- every AI tick, as a goal of its own: steering actions
--   function Crawler:on_hurt(mob, hit) end     -- about to take damage: hit:set_amount(n), hit:cancel()
--   function Crawler:on_death(mob, cause) end  -- it died, by any cause: cause.damage_type, .causing, .player (or nil)
--   function Crawler:on_interact(mob, player, held) end -- right-clicked; return true to take the click
--
-- A callback is wired to the game's hook for the class's kind the moment it
-- is defined, so a kind without one costs nothing each tick.
local Goal = require("modkit.goal")
local Mob = require("modkit.mob")
local Player = require("modkit.player")

local Entity = {}

-- Which hook each callback listens to, and how the hook's arguments become
-- the callback's.
local CALLBACKS = {
  on_spawned = { "mob_spawned", function(e, dimension, kind, x, y, z, natural)
    e:on_spawned({ dimension = dimension, kind = kind, x = x, y = y, z = z, natural = natural })
  end },
  on_tick = { "mob_tick", function(e, dimension, mob, data)
    e:on_tick(Mob.host(mob, dimension, data))
  end },
  on_hurt = { "mob_hurt", function(e, mob, damage_type, causing, direct, amount)
    local hit = {
      damage_type = damage_type, causing = causing, direct = direct, amount = amount,
      set_amount = function(self, n) self.amount = n; horizon.set_amount(n) end,
      cancel = function(self) self.canceled = true; horizon.cancel() end,
    }
    e:on_hurt(Mob.host(mob, nil, nil), hit)
  end },
  on_death = { "mob_died", function(e, dimension, mob, cause, data)
    e:on_death(Mob.host(mob, dimension, data), cause)
  end },
  on_interact = { "mob_interact", function(e, dimension, mob, player, held, data)
    if e:on_interact(Mob.host(mob, dimension, data), Player.wrap(player), held) == true then horizon.cancel() end
  end },
}

Entity.__index = Entity
--- Defining a callback (`function E:on_tick(mob) ... end`) registers its hook
--- for this kind, once.
Entity.__newindex = function(self, key, value)
  rawset(self, key, value)
  local cb = CALLBACKS[key]
  if cb and value ~= nil then self:_listen(key, cb[1], cb[2]) end
end

function Entity.new(mod, id)
  local e = setmetatable({ mod = mod, id = id, goal_list = {}, target_list = {}, replace_goals = false, _hooked = {} }, Entity)
  horizon.on("mob_ai_register", function(mob) e:_register(mob) end, id)
  return e
end

function Entity:_listen(name, hook, adapt)
  if self._hooked[hook] then return end
  self._hooked[hook] = true
  local e = self
  horizon.on(hook, function(...)
    if e[name] then adapt(e, ...) end
  end, self.id)
end

--- `{ {priority, goal}, ... }`: the goals every mob of this type gets.
function Entity:goals(list)
  for _, row in ipairs(list) do self.goal_list[#self.goal_list + 1] = row end
  return self
end

function Entity:target_goals(list)
  for _, row in ipairs(list) do self.target_list[#self.target_list + 1] = row end
  return self
end

local function short(id) return (id:gsub("^[^:]*:", "")) end

--- As a mob of this type sets its goals up (`mob_ai_register`).
function Entity:_register(mob)
  if self.replace_goals then
    horizon.clear_goals()
    horizon.clear_target_goals()
  end
  local base = short(self.id)
  for i, row in ipairs(self.goal_list) do
    horizon.add_goal(row[1], row[2]:register(base .. "." .. (row[2].def.name or ("goal" .. i))))
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

--- Nothing to install any more: each class listens for its own kind.
function Entity.install(mod) end

return Entity
