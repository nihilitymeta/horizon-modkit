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
local modkit = { VERSION = "0.4.0" }

local Mob = require("modkit.mob")
local Goal = require("modkit.goal")
local Entity = require("modkit.entity")
local Block = require("modkit.block")
local Item = require("modkit.item")
local Players = require("modkit.players")

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

--- The players class: callbacks on what every player does.
function Mod:players()
  if not self._players then self._players = Players.new(self) end
  return self._players
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

--- A command of the mod's: `M:command("mymod count [kind:word]", 2, function(player, args) ... end)`;
--- `horizon.feedback(text)` answers the player. Level 0 is everyone, 4 the operators.
function Mod:command(usage, level, fn)
  if type(level) == "function" then level, fn = 0, level end
  horizon.command(usage, level, fn)
end

--- A hook handler as the game takes it (`horizon.on`), for what the classes
--- do not cover.
function Mod:on(hook, fn)
  horizon.on(hook, fn)
end

function modkit.log(msg) horizon.log(msg) end
--- Effects in the world and on a player (docs/api.md): the engine's actions, from a callback.
function modkit.sound(name, x, y, z, volume, pitch) horizon.sound(name, x, y, z, volume, pitch) end
function modkit.particles(name, x, y, z, count, spread, speed) horizon.particles(name, x, y, z, count, spread, speed) end
function modkit.title(player, text, subtitle)
  horizon.title(player.uuid or player, text)
  if subtitle then horizon.subtitle(player.uuid or player, subtitle) end
end
function modkit.tell(player, text) horizon.tell(player.uuid or player, text) end
function modkit.action_bar(player, text) horizon.action_bar(player.uuid or player, text) end
function modkit.distance(a, b) return horizon.distance(a, b) end

return modkit
