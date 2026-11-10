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

-- The mod object: the namespace of its entities, blocks and items.
local Mod = {}
Mod.__index = Mod

--- Creates a new mod object. Call it once per mod, at the top of init.lua.
function modkit.mod(id: string)
  local m = setmetatable({ id = id, entities = {}, blocks = {}, items = {} }, Mod)
  Entity.install(m)
  Block.install(m)
  return m
end

--- Gets the full id of `name`: `name` itself when it has a namespace,
--- otherwise `<mod>:<name>`.
function Mod:qualify(name: string): string
  if name:find(":", 1, true) then return name end
  return self.id .. ":" .. name
end

--- Gets the entity class for the entity type `name`, creating it the first
--- time. A name without a namespace is the mod's own; "minecraft:zombie"
--- adds behaviour to every zombie.
function Mod:entity(name: string)
  local id = self:qualify(name)
  local e = self.entities[id]
  if not e then
    e = Entity.new(self, id)
    self.entities[id] = e
  end
  return e
end

--- Gets the block class for the block `name`, the mod's own or a vanilla
--- one, creating it the first time.
function Mod:block(name: string)
  local id = self:qualify(name)
  local b = self.blocks[id]
  if not b then
    b = Block.new(self, id)
    self.blocks[id] = b
  end
  return b
end

--- Gets the players class, which holds the callbacks for what every player
--- does, creating it the first time.
function Mod:players()
  if not self._players then self._players = Players.new(self) end
  return self._players
end

--- Gets the item class for the item `name`, the mod's own or a vanilla one,
--- creating it the first time.
function Mod:item(name: string)
  local id = self:qualify(name)
  local i = self.items[id]
  if not i then
    i = Item.new(self, id)
    self.items[id] = i
  end
  return i
end

--- Adds a command to the server's command tree:
--- `M:command("mymod count [kind:word]", 2, function(player, args) ... end)`.
--- `level` is the operator level a player needs (0 everyone, 2 operators,
--- 4 the console) and may be left out. Inside `fn`, `horizon.feedback(text)`
--- answers the player.
function Mod:command(usage: string, level: number | ((player: Player, args: CommandArgs) -> ()), fn: ((player: Player, args: CommandArgs) -> ())?)
  local run: any = fn
  local at: any = level
  if type(level) == "function" then at, run = 0, level end
  horizon.command(usage, at, function(player, args) return run(Player.wrap(player), args) end)
end

--- Gets the mod's settings from `config/<id>.json` in the game folder.
--- Keys the file lacks are filled in from `defaults`, and the file is saved
--- when that added any. Works at load.
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
--- Saves the settings table back to the mod's settings file.
function Mod:save_config(c: Data?) horizon.save_config(c or self._config) end

--- Registers a handler for an engine hook, as `horizon.on` does, for what
--- the classes do not cover: `M:on("explosion_detonate", fn)`,
--- `M:on("entity_join_level", fn, "minecraft:arrow")`,
--- `M:on("projectile_impact", fn, "minecraft:snowball")`, `M:on("living_heal", fn)`.
function Mod:on(hook: string, fn: (...any) -> (), kind: string?)
  (horizon.on :: any)(hook, fn, kind)
end

--- Writes a line to the game log, tagged with the mod's id.
function modkit.log(msg: string) horizon.log(msg) end
-- Effects in the world and on a player: the engine's actions, from a
-- callback with a host.
--- Plays a sound for the players in range of a position, as `/playsound` does.
function modkit.sound(name: string, x: number, y: number, z: number, volume: number?, pitch: number?) horizon.sound(name, x, y, z, volume, pitch) end
--- Shows particles to the players near a position, as `/particle` does.
function modkit.particles(name: string, x: number, y: number, z: number, count: number?, spread: number?, speed: number?) horizon.particles(name, x, y, z, count, spread, speed) end
-- A player as the engine's helpers take one: a table's uuid, or a name or UUID as given.
local function who(player: Player | string): string
  if type(player) == "table" then return player.uuid end
  return player
end
--- Shows a title, and an optional subtitle, across a player's screen.
function modkit.title(player: Player | string, text: string, subtitle: string?)
  horizon.title(who(player), text)
  if subtitle then horizon.subtitle(who(player), subtitle) end
end
--- Sends a chat line to one player.
function modkit.tell(player: Player | string, text: string) horizon.tell(who(player), text) end
--- Shows a line over a player's hotbar.
function modkit.action_bar(player: Player | string, text: string) horizon.action_bar(who(player), text) end
--- Gets the distance between two positions, in blocks.
function modkit.distance(a: Vec3, b: Vec3): number return horizon.distance(a, b) end
-- The world: the engine's actions and reads, from a callback with a host.
--- Sets a block, as `/setblock` does. Not in a random or scheduled tick.
function modkit.set_block(x: number, y: number, z: number, id: string, props: Props?, flags: number?) horizon.set_block(x, y, z, id, props, flags) end
--- Fills a box with one block state, as `/fill ... strict` does.
function modkit.fill(x1: number, y1: number, z1: number, x2: number, y2: number, z2: number, id: string, props: Props?) horizon.fill(x1, y1, z1, x2, y2, z2, id, props) end
--- Drops an item entity of `count` (1) of a plain item at a position.
function modkit.drop_item(x: number, y: number, z: number, id: string, count: number?) horizon.drop_item(x, y, z, id, count) end
--- Throws a falling block from a position at a velocity in blocks per tick.
function modkit.falling_block(x: number, y: number, z: number, id: string, vx: number?, vy: number?, vz: number?) horizon.falling_block(x, y, z, id, vx, vy, vz) end
--- Gets the `{block, sky}` light at a position, each 0 to 15.
function modkit.light(x: number, y: number, z: number): Light return horizon.light(x, y, z) end
--- Gets the height of a column by a heightmap (`world_surface` by default),
--- or nil where nothing is loaded.
function modkit.surface_height(x: number, z: number, heightmap: string?): number? return horizon.surface_height(x, z, heightmap) end
--- Runs a command as the server console does. Inside a player's own
--- callback, queue it with `horizon.after(1, ...)` instead.
function modkit.run_command(line: string) horizon.run_command(line) end
--- Reads a data file of the game's resources: JSON as a table, any other
--- file as a string, nil when there is none.
function modkit.data(path: string): any return horizon.data(path) end
--- Gives a status effect to a mob (by id) or a player (a table, a name or a
--- UUID), as `/effect give` does: 200 ticks at amplifier 0 by default.
function modkit.effect(target: number | string | Player, name: string, ticks: number?, amplifier: number?) horizon.effect(target, name, ticks or 200, amplifier or 0) end

return modkit
