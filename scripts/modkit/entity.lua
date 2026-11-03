-- An entity class: goals and callbacks for one entity type, the mod's own
-- (declared in its data) or a vanilla kind.
--
--   local Crawler = M:entity("crawler")
--   Crawler:goals { {1, Hunt}, {5, modkit.goals.Wander()} }
--   Crawler:target_goals { ... }
--   function Crawler:on_tick(mob) end          -- every AI tick, as a goal of its own
--   function Crawler:on_spawned(ev) end        -- ev: dimension, x, y, z, natural
--   Crawler.replace_goals = true               -- drop the vanilla goals first (a mod type with "goals": "template")
local Goal = require("modkit.goal")

local Entity = {}
Entity.__index = Entity

function Entity.new(mod, id)
  return setmetatable({ mod = mod, id = id, goal_list = {}, target_list = {}, replace_goals = false }, Entity)
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
  if self.on_tick then
    local entity = self
    if not self._tick_goal then
      self._tick_goal = Goal.new {
        flags = {},
        every_tick = true,
        can_use = function() return true end,
        tick = function(state, mob) entity:on_tick(mob, state) end,
      }
    end
    horizon.add_goal(99, self._tick_goal:register(base .. ".tick"))
  end
end

--- Installs the mod's handlers once: the game's events reach the classes.
function Entity.install(mod)
  horizon.on("mob_ai_register", function(mob)
    local e = mod.entities[mob.kind]
    if e then e:_register(mob) end
  end)
  horizon.on("mob_spawned", function(dimension, kind, x, y, z, natural)
    local e = mod.entities[kind]
    if e and e.on_spawned then
      e:on_spawned({ dimension = dimension, kind = kind, x = x, y = y, z = z, natural = natural })
    end
  end)
end

return Entity
