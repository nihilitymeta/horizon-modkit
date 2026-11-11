-- Mobs and goals: a class per entity type, the mod's own or a vanilla kind,
-- with its goals and callbacks (guide: docs/guides/mobs.md; reference:
-- docs/api.md, "Entity classes", "Goals", "The mob"). The type is declared in
-- scripts/registry.lua as a pig with `goals = "none"`, so everything it
-- does is here. `mob` is the mob's view (position, health, target...) with
-- actions the game applies after the callback, and `mob.data`, the mob's own
-- saved table, where the feedings below are counted.
-- See it in game: /example spawn (or its egg); it wanders, comes to a player
-- within eight blocks, eats wheat from a hand (three feedings make the feeder
-- a keeper, by name), shrugs off fire, lands softly, and says how it died.
local modkit = require("@modkit")
local M = require("@example/mod")
local Players = require("@example/players")

local Mob = M:entity("example_mob")

-- A goal of the mod's own: come to the nearest player within eight blocks.
-- `flags` say what it locks (move, look, jump, target), as vanilla's goals
-- do; `self` is this goal's table on this mob, with self:every(name, ticks)
-- and self:cooldown(name, ticks).
local Approach = modkit.Goal {
  flags = { "move", "look" },
  can_use = function(self, mob) return mob:player_within(8) end,
  tick = function(self, mob)
    local p = mob.nearest_player
    if not p then return end
    mob:look_at(p.x, p.y + 1.6, p.z)
    if mob.navigation_done or self:every("path", 20) then mob:navigate_to(p.x, p.y, p.z, 1.0) end
  end,
  stop = function(self, mob) mob:stop_navigation() end,
}

-- Its goals, lower priority first; modkit.goals has ready-made ones.
Mob:goals {
  { 1, Approach },
  { 5, modkit.goals.Wander(6, 80, 16) },
}

-- A player right-clicked it, before the mob and the item act: wheat feeds it
-- (healed, the feeder thanked, a count kept in the mob's own saved table)
-- and counts for the feeder too, in their own saved table: at three feedings
-- they are nicknamed a keeper (next tick, from a timer: a nickname is set
-- where no player's own action is under way) and their chat lines carry it
-- (scripts/server/example/players.lua). The click is taken. An empty hand reads the
-- mob's count.
function Mob:on_interact(mob, player, held)
  local fed = mob.data
  if held and held.item == "minecraft:wheat" then
    fed.fed = (fed.fed or 0) + 1
    mob:heal(4)
    modkit.particles("minecraft:heart", mob.position.x, mob.position.y + 1, mob.position.z, 5, 0.3, 0.02)
    player:action_bar(("fed %d time(s)"):format(fed.fed))
    horizon.log(("EXAMPLE mob fed by %s"):format(player.name))
    local mine = player:data()
    if mine then
      mine.fed = (mine.fed or 0) + 1
      if mine.fed >= 3 then Players.keepers[player.uuid] = true end
      if mine.fed == 3 then
        local name = player.name
        horizon.after(1, function()
          local p = horizon.player(name)
          if p then modkit.player(p):nickname(name .. " the Keeper") end
        end)
        horizon.log(("EXAMPLE keeper: %s fed three example mobs"):format(player.name))
      end
    end
    return true
  end
  if held == nil then player:tell(("this one was fed %d time(s), has %.0f/%.0f hp"):format(fed.fed or 0, mob.health or 0, mob.max_health or 0)) end
  return false
end

-- About to take damage: hit.damage_type, hit.amount; hit:set_amount(n),
-- hit:cancel(). The game is mid-hit: `mob` is id and kind only here.
function Mob:on_hurt(mob, hit)
  if hit.damage_type == "minecraft:on_fire" or hit.damage_type == "minecraft:in_fire" then hit:cancel() end
end

-- About to land: no fall damage.
function Mob:on_fall(mob, fall) fall:cancel() end

-- Died: `cause` has damage_type, causing (a mob id) and player (the killer's
-- uuid, or nil).
function Mob:on_death(mob, cause)
  local who = "the world"
  if cause.player then
    local p = horizon.player(cause.player)
    who = p and p.name or cause.player
  end
  horizon.broadcast(("an example mob died of %s, by %s"):format(cause.damage_type, who))
  horizon.log("EXAMPLE mob died")
end

-- Its loot is about to drop (the table in scripts/registry.lua): a player's
-- kill drops a feather too.
function Mob:on_drops(mob, drops, source)
  if source.player then drops[#drops + 1] = { id = "example_mod:example_item", count = 1 } end
end

return Mob
