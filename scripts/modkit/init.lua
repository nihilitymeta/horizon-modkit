-- Horizon Modkit: write a mod's entities, blocks and goals as classes with
-- lifecycle callbacks, over the game's `horizon.*` hook API
-- (whos-carmen/horizon, docs/lua-bindings.md).
--
--   local modkit = require("@modkit")
--   local M = modkit.mod("my_mod")
--   local Crawler = M:entity("crawler")          -- data/my_mod/horizon/entity_type/crawler.json
--   Crawler:goals { {1, modkit.Goal { ... }}, {5, modkit.goals.Wander(6)} }
--   function Crawler:on_tick(mob) ... end
--   local Hive = M:block("hive")
--   function Hive:on_random_tick(block) ... end
--
-- The library runs inside the mod's own Lua state; one `modkit.mod` per mod.
-- The version is the manifest's (horizon-mod.toml), the one place it is
-- written: a mod that depends on the modkit reads it from the engine's
-- `horizon.libraries`, the modkit's own scripts from `horizon.mod_version`.
local modkit = { VERSION = horizon.libraries.horizon_modkit or horizon.mod_version }

local Mob = require("@modkit/mob")
local Goal = require("@modkit/goal")
local Entity = require("@modkit/entity")
local Block = require("@modkit/block")
local Item = require("@modkit/item")
local Players = require("@modkit/players")
local Player = require("@modkit/player")

modkit.Mob = Mob
modkit.Player = Player
modkit.player = Player.wrap
modkit.Goal = Goal.new
modkit.goals = require("@modkit/goals")

--- The mod itself: the namespace of its entities and blocks.
local Mod = {}
Mod.__index = Mod

function modkit.mod(id: string)
  local m = setmetatable({ id = id, entities = {}, blocks = {}, items = {} }, Mod)
  Entity.install(m)
  Block.install(m)
  return m
end

--- A full id: `name` as given when it has a namespace, else `<mod>:<name>`.
function Mod:qualify(name: string): string
  if name:find(":", 1, true) then return name end
  return self.id .. ":" .. name
end

--- An entity class for the entity type `name` (the mod's own, declared in
--- its data, or a vanilla kind such as "minecraft:zombie" to add goals to).
function Mod:entity(name: string)
  local id = self:qualify(name)
  local e = self.entities[id]
  if not e then
    e = Entity.new(self, id)
    self.entities[id] = e
  end
  return e
end

--- A block class for the block `name` (the mod's own, or a vanilla one).
function Mod:block(name: string)
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
function Mod:item(name: string)
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
function Mod:command(usage: string, level: number | ((player: Player, args: CommandArgs) -> ()), fn: ((player: Player, args: CommandArgs) -> ())?)
  local run: any = fn
  local at: any = level
  if type(level) == "function" then at, run = 0, level end
  horizon.command(usage, at, function(player, args) return run(Player.wrap(player), args) end)
end

--- The mod's settings (`config/<id>.json` in the game folder) with
--- `defaults` filled in for the keys the file lacks, saved when that added
--- any, so the file is there to edit after the first run. At load too.
function Mod:config(defaults: Data?): Data
  local c = horizon.config()
  local added = false
  for k, v in pairs(defaults or {}) do
    if c[k] == nil then c[k] = v; added = true end
  end
  if added then horizon.save_config(c) end
  self._config = c
  return c
end
--- Writes the settings back (after a command changed them).
function Mod:save_config(c: Data?) horizon.save_config(c or self._config) end

--- A hook handler as the game takes it (`horizon.on`), for what the classes
--- do not cover: `M:on("explosion", fn)`, `M:on("entity_joined", fn, "minecraft:arrow")`,
--- `M:on("projectile_impact", fn, "minecraft:snowball")`, `M:on("mob_heal", fn)`.
function Mod:on(hook: string, fn: (...any) -> (), kind: string?)
  (horizon.on :: any)(hook, fn, kind)
end

function modkit.log(msg: string) horizon.log(msg) end
--- Effects in the world and on a player (docs/api.md): the engine's actions, from a callback.
function modkit.sound(name: string, x: number, y: number, z: number, volume: number?, pitch: number?) horizon.sound(name, x, y, z, volume, pitch) end
function modkit.particles(name: string, x: number, y: number, z: number, count: number?, spread: number?, speed: number?) horizon.particles(name, x, y, z, count, spread, speed) end
--- A player as the engine's helpers take one: a table's uuid, or a name or UUID as given.
local function who(player: Player | string): string
  if type(player) == "table" then return player.uuid end
  return player
end
function modkit.title(player: Player | string, text: string, subtitle: string?)
  horizon.title(who(player), text)
  if subtitle then horizon.subtitle(who(player), subtitle) end
end
function modkit.tell(player: Player | string, text: string) horizon.tell(who(player), text) end
function modkit.action_bar(player: Player | string, text: string) horizon.action_bar(who(player), text) end
function modkit.distance(a: Vec3, b: Vec3): number return horizon.distance(a, b) end
--- The world (docs/api.md): the engine's actions and reads, from a callback with a host.
function modkit.set_block(x: number, y: number, z: number, id: string, props: Props?, flags: number?) horizon.set_block(x, y, z, id, props, flags) end
function modkit.fill(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, id: string, props: Props?) horizon.fill(x1, y1, z1, x2, y2, z2, id, props) end
function modkit.drop_item(x: number, y: number, z: number, id: string, count: number?) horizon.drop_item(x, y, z, id, count) end
function modkit.falling_block(x: number, y: number, z: number, id: string, vx: number?, vy: number?, vz: number?) horizon.falling_block(x, y, z, id, vx, vy, vz) end
function modkit.light(x: number, y: number, z: number): Light return horizon.light(x, y, z) end
function modkit.surface_height(x: number, z: number, heightmap: string?): number? return horizon.surface_height(x, z, heightmap) end
--- A command as the server's console runs it (not inside a player's own
--- callback: there it is queued for the next tick).
function modkit.run_command(line: string) horizon.run_command(line) end
function modkit.data(path: string): any return horizon.data(path) end
--- A status effect on a mob (by id) or a player (a table, a name or a UUID).
function modkit.effect(target: number | string | Player, name: string, ticks: number?, amplifier: number?) horizon.effect(target, name, ticks or 200, amplifier or 0) end

return modkit
