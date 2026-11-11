-- Players: one class for what every player does (guide:
-- docs/guides/players-and-events.md; reference: docs/api.md, "The players class").
-- `player` is the engine's table (uuid, name, position, dimension,
-- game_mode, health, held) with methods: give, take, effect, tell, title,
-- action_bar, data... See it in game: join (a title, a feather the first
-- time, a count of visits), say "ping" in the chat, break and place blocks,
-- die, try a bed with an example mob about, feed three example mobs and chat.
local modkit = require("@modkit")
local M = require("@example/mod")
local cfg = require("@example/timers_and_data")

local Players = M:players()

-- Who fed three example mobs, by uuid (scripts/server/example/mob.lua fills it, and
-- the join below): the chat callback has no host to read the saved data
-- with, so it reads this.
Players.keepers = {}

-- Joined: a title with the greeting from the settings, a visit counted in
-- the player's own saved table, a feather on the first visit. A give to a
-- player from inside their own join is done next tick, from a timer, where
-- every player is reachable.
function Players:on_join(player)
  modkit.title(player, cfg.greeting, "Example Mod on modkit " .. modkit.VERSION)
  local mine = player:data()
  if mine then
    if (mine.fed or 0) >= 3 then
      Players.keepers[player.uuid] = true
    end
    mine.visits = (mine.visits or 0) + 1
    if mine.visits == 1 then
      local name = player.name
      horizon.after(1, function()
        local p = horizon.player(name)
        if p then
          modkit.player(p):give("example_mod:example_item", 1)
        end
      end)
    end
    horizon.log(("EXAMPLE player joined: %s, visit %d"):format(player.name, mine.visits))
  end
end

function Players:on_leave(player)
  horizon.log(("EXAMPLE player left: %s"):format(player.name))
end

-- Died (`cause` is the death message's key, such as death.attack.lava) and
-- came back. The event names the dead player by uuid only.
function Players:on_death(uuid, cause)
  local p = horizon.player(uuid)
  local name = p and p.name or uuid
  horizon.broadcast(("%s died: %s"):format(name, cause or "unknown"))
  horizon.log(("EXAMPLE player died: %s"):format(cause or "unknown"))
end
function Players:on_respawn(player)
  player:action_bar("welcome back")
end

-- A block broken (return true to keep it) or placed.
function Players:on_break_block(player, block)
  if block.id == "minecraft:bedrock" then
    return true
  end
  horizon.log(("EXAMPLE player broke %s"):format(block.id))
  return false
end
function Players:on_place_block(player, block, item)
  horizon.log(("EXAMPLE player placed %s"):format(block.id))
end

-- About to pick an item up (return true to leave it on the ground).
function Players:on_pickup(player, item, count)
  if item == "minecraft:poisonous_potato" then
    return true
  end
  return false
end

-- A chat line, before anyone sees it: return a string to answer the sender,
-- true to drop it. Only uuid and name are known here, and no saved data: a
-- keeper is known from the set above.
function Players:on_chat(player, line)
  if line == "ping" then
    horizon.log(("EXAMPLE chat from %s"):format(player.name))
    return "pong"
  end
  if Players.keepers[player.uuid] then
    horizon.log(("EXAMPLE keeper chat from %s"):format(player.name))
    return "You keep example mobs."
  end
  return nil
end

-- Entering a bed: return true to keep them out. No sleep while example mobs
-- roam. A cancel ends the dispatch: another mod's on_sleep is not asked.
function Players:on_sleep(player, x, y, z)
  local roaming = 0
  for _, m in ipairs(horizon.mobs()) do
    if m.kind == "example_mod:example_mob" then
      roaming = roaming + 1
    end
  end
  if roaming > 0 then
    player:action_bar(("%d example mob(s) roam: no sleep tonight"):format(roaming))
    horizon.log(("EXAMPLE player %s may not sleep: %d example mob(s) roam"):format(player.name, roaming))
    return true
  end
  horizon.log(("EXAMPLE player sleeps at %d %d %d"):format(x, y, z))
  return false
end

return Players
