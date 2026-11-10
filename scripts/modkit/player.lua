-- A player as a callback sees it: the engine's table (`uuid`, `name`,
-- `dimension`, `position`, `game_mode`, `health`, `held` on a command's player
-- table only) with methods that ask the game to act on them, applied after
-- the call, and reads answered at once. Any callback with a host. Only
-- `command` handlers name the hand: elsewhere the engine hands out no `held`.
--
--   function Players:on_join(player)
--     player:give("minecraft:bread", 3)
--     player:effect("minecraft:regeneration", 100)
--     player:title("Welcome", player.name)
--     if player:count("minecraft:diamond") > 0 then ... end
--   end
local Held = require("@modkit/held")

local Player = {}
Player.__index = Player

--- Adds the player methods to the engine's player table, and returns it.
--- A table that already has them is returned as it is. A table without the
--- hand names it from the selected-slot tracking (`held` is `{item, count,
--- plain}`, or absent): a command's player table keeps the engine's own.
function Player.wrap(t: Player)
  local raw: any = t
  if raw == nil or getmetatable(raw) == Player then return raw end
  if raw.held == nil then
    Held.track()
    raw.held = Held.of()
  end
  return setmetatable(raw, Player)
end

-- The inventory.
--- Gives `n` (1) of a plain item where it fits. Nothing drops.
function Player:give(id: string, n: number?) horizon.give_items(self.uuid, id, n or 1) end
--- Takes up to `n` (1) of a plain item, the main hand first.
function Player:take(id: string, n: number?) horizon.take_items(self.uuid, id, n or 1) end
--- Gets the 36 slots by number (1 to 36, the hotbar first) as
--- `{id, count, damage, plain}`, or nil. An empty slot is absent.
function Player:inventory(): Inventory? return horizon.inventory(self.uuid) end
--- Gets how many of a plain item the player carries.
function Player:count(id: string): number return horizon.count_items(self.uuid, id) or 0 end
--- Gets every plain item the player carries, with how many, by id.
function Player:carried(): Carried return horizon.carried_items(self.uuid) or {} end

-- Life.
--- Gives a status effect for `ticks` (200) at `amplifier` (0), as
--- `/effect give` does.
function Player:effect(name: string, ticks: number?, amplifier: number?) horizon.effect(self.uuid, name, ticks or 200, amplifier or 0) end
--- Gives experience points, as an orb does.
function Player:experience(points: number) horizon.give_experience(self.uuid, points) end
--- Gives levels; a negative number takes them away.
function Player:levels(n: number) horizon.give_levels(self.uuid, n) end
--- Sets the name shown in chat and the tab list; nil shows their own again.
function Player:nickname(name: string?) horizon.set_nickname(self.uuid, name) end

-- Words and effects.
--- Sends a chat line to the player.
function Player:tell(text: string) horizon.tell(self.uuid, text) end
--- Shows a line over the player's hotbar.
function Player:action_bar(text: string) horizon.action_bar(self.uuid, text) end
--- Shows a title, and an optional subtitle, across the player's screen.
function Player:title(text: string, subtitle: string?)
  horizon.title(self.uuid, text)
  if subtitle then horizon.subtitle(self.uuid, subtitle) end
end
--- Sets how long titles fade in, stay and fade out, in ticks.
function Player:title_times(fade_in: number, stay: number, fade_out: number) horizon.title_times(self.uuid, fade_in, stay, fade_out) end

-- Reading.
--- Gets the mod's saved table on the player (`horizon.player_data`), or nil.
function Player:data(): Data? return horizon.player_data(self.uuid) end
--- Gets the first block within `distance` (64) along the player's look, or nil.
function Player:raycast(distance: number?): Raycast? return horizon.raycast(self.uuid, distance) end
--- Gets the id of the block under the player's feet.
function Player:block_below(): string
  local p = self.position
  return horizon.block(math.floor(p.x), math.floor(p.y) - 1, math.floor(p.z))
end
--- Gets the distance to a position, in blocks.
function Player:distance_to(p: Vec3): number return horizon.distance(self.position, p) end

return Player
