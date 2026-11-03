-- A player as a callback sees it: the engine's table (`uuid`, `name`,
-- `dimension`, `position`, `game_mode`, `health`, `held` for the acting
-- player) with methods that ask the game to act on them, applied after the
-- call, and reads answered at once. Any callback with a host.
--
--   function Players:on_join(player)
--     player:give("minecraft:bread", 3)
--     player:effect("minecraft:regeneration", 100)
--     player:title("Welcome", player.name)
--     if player:count("minecraft:diamond") > 0 then ... end
--   end
local Player = {}
Player.__index = Player

--- Wraps the engine's player table (once; a wrapped one is returned as is).
function Player.wrap(t: Player)
  local raw: any = t
  if raw == nil or getmetatable(raw) == Player then return raw end
  return setmetatable(raw, Player)
end

-- The inventory.
--- Gives `n` (1) of a plain item where it fits; nothing drops.
function Player:give(id: string, n: number?) horizon.give_items(self.uuid, id, n or 1) end
--- Takes up to `n` (1) of a plain item, the main hand first.
function Player:take(id: string, n: number?) horizon.take_items(self.uuid, id, n or 1) end
--- The 36 slots by number (1 to 36, the hotbar first) of `{id, count, damage, plain}`, or nil.
function Player:inventory(): Inventory? return horizon.inventory(self.uuid) end
--- How many of a plain item they carry.
function Player:count(id: string): number return horizon.count_items(self.uuid, id) or 0 end
--- Every plain item they carry, with how many, by id.
function Player:carried(): Carried return horizon.carried_items(self.uuid) or {} end

-- Life.
--- A status effect for `ticks` (200) at `amplifier` (0), as `/effect give`.
function Player:effect(name: string, ticks: number?, amplifier: number?) horizon.effect(self.uuid, name, ticks or 200, amplifier or 0) end
--- Experience points, as an orb gives them.
function Player:experience(points: number) horizon.give_experience(self.uuid, points) end
--- Levels; negative takes them off.
function Player:levels(n: number) horizon.give_levels(self.uuid, n) end
--- The name shown in chat and the tab list; nil shows their own again.
function Player:nickname(name: string?) horizon.set_nickname(self.uuid, name) end

-- Words and effects.
function Player:tell(text: string) horizon.tell(self.uuid, text) end
function Player:action_bar(text: string) horizon.action_bar(self.uuid, text) end
function Player:title(text: string, subtitle: string?)
  horizon.title(self.uuid, text)
  if subtitle then horizon.subtitle(self.uuid, subtitle) end
end
function Player:title_times(fade_in: number, stay: number, fade_out: number) horizon.title_times(self.uuid, fade_in, stay, fade_out) end

-- Reading.
--- The mod's saved table on this player (`horizon.player_data`), or nil.
function Player:data(): Data? return horizon.player_data(self.uuid) end
--- The first block within `distance` (64) along their look, or nil.
function Player:raycast(distance: number?): Raycast? return horizon.raycast(self.uuid, distance) end
--- The block under their feet, by id.
function Player:block_below(): string
  local p = self.position
  return horizon.block(math.floor(p.x), math.floor(p.y) - 1, math.floor(p.z))
end
function Player:distance_to(p: Vec3): number return horizon.distance(self.position, p) end

return Player
