-- Horizon Modkit: write a mod's entities, blocks and goals as classes with
-- lifecycle callbacks, over the game's `horizon.*` hook API
-- (whos-carmen/horizon, docs/lua-bindings.md).
--
--   local modkit = require("modkit")
--   local M = modkit.mod("my_mod")
--   local Crawler = M:entity("crawler")          -- data/my_mod/horizon/entity_type/crawler.json
--   Crawler:goals { {1, modkit.Goal { ... }}, {5, modkit.goals.Wander(6)} }
--   function Crawler:on_tick(mob) ... end
--   local Hive = M:block("hive")
--   function Hive:on_random_tick(block) ... end
--
-- The library runs inside the mod's own Lua state; one `modkit.mod` per mod.
local modkit = { VERSION = "0.3.0" }

local Mob = require("modkit.mob")
local Goal = require("modkit.goal")
local Entity = require("modkit.entity")
local Block = require("modkit.block")
local Item = require("modkit.item")

modkit.Mob = Mob
modkit.Goal = Goal.new
modkit.goals = require("modkit.goals")

--- The mod itself: the namespace of its entities and blocks.
local Mod = {}
Mod.__index = Mod

function modkit.mod(id)
  local m = setmetatable({ id = id, entities = {}, blocks = {}, items = {} }, Mod)
  Entity.install(m)
  Block.install(m)
  return m
end

--- A full id: `name` as given when it has a namespace, else `<mod>:<name>`.
function Mod:qualify(name)
  if name:find(":", 1, true) then return name end
  return self.id .. ":" .. name
end

--- An entity class for the entity type `name` (the mod's own, declared in
--- its data, or a vanilla kind such as "minecraft:zombie" to add goals to).
function Mod:entity(name)
  local id = self:qualify(name)
  local e = self.entities[id]
  if not e then
    e = Entity.new(self, id)
    self.entities[id] = e
  end
  return e
end

--- A block class for the block `name` (the mod's own, or a vanilla one).
function Mod:block(name)
  local id = self:qualify(name)
  local b = self.blocks[id]
  if not b then
    b = Block.new(self, id)
    self.blocks[id] = b
  end
  return b
end

--- An item class for the item `name` (the mod's own, or a vanilla one).
function Mod:item(name)
  local id = self:qualify(name)
  local i = self.items[id]
  if not i then
    i = Item.new(self, id)
    self.items[id] = i
  end
  return i
end

--- A hook handler as the game takes it (`horizon.on`), for what the classes
--- do not cover.
function Mod:on(hook, fn)
  horizon.on(hook, fn)
end

function modkit.log(msg) horizon.log(msg) end
function modkit.distance(a, b) return horizon.distance(a, b) end

return modkit
