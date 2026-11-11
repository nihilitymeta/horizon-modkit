# Players and Events

Everything players do reaches one class, `M:players()`, with one callback for each event.

The examples on this page come from the example mod:

- [scripts/server/example/players.lua](../../examples/example_mod/scripts/server/example/players.lua): the players class
- [scripts/server/example/mob.lua](../../examples/example_mod/scripts/server/example/mob.lua): counting the players who feed a mob

The reference is [The players class](../api.md#the-players-class) and [The player](../api.md#the-player).

## Greeting a player

When a player joins, this callback shows a title, counts the visit in the player's saved table, and gives a feather
on the first visit:

```lua
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
```

## The events

| Callback | When it runs |
|---|---|
| `on_join`, `on_leave`, `on_respawn` | a player joins, leaves, or respawns |
| `on_death(uuid, cause)` | a player dies; `cause` is the death message's key. The dead player is named by uuid only |
| `on_break_block(player, block)` | a player breaks a block. Return true to keep it. The event names nobody: `player` is the acting player, the one who acted |
| `on_place_block(player, block, item)` | a player places a block. The event names nobody: `player` is the acting player, the one who acted |
| `on_pickup(player, item, count)` | a player is about to pick up items. Return true to leave them |
| `on_chat(player, line)` | a chat line. Return a string to answer the sender, or true to drop it |
| `on_command(player, line)` | a command, before it runs. Return true to stop it; `player:reply` answers |
| `on_sleep(player, x, y, z)` | a player is about to enter a bed. Return true to keep them out |
| `on_hurt`, `on_fall`, `on_knockback` | a player is about to take damage, land, or be knocked back |
| `on_exp` | a player is about to gain experience |
| `on_open_menu` | a player opens a menu |
| `on_change_dimension` | a player arrives in another dimension |
| `on_tick(player)` | every tick of every player, each time with that player. Keep it light |

## The player table

In these callbacks, and in every other callback that names a player, `player` is a table with:

- the fields `uuid`, `name`, `position`, `dimension`, `game_mode`, `health` and `held` (the selected slot, or
  nil; a command's table carries the engine's own)
- the methods `give`, `take`, `inventory`, `count`, `effect`, `experience`, `levels`, `nickname`, `tell`,
  `action_bar`, `title`, `data` (the mod's saved table on the player), `raycast` and `block_below`

A player that you read from the world with `horizon.player(name)` gets the methods from `modkit.player(t)`.

## Reaching other players

Inside a player's own callback, such as their click or their command, only that player is reached. A give to
anyone else does nothing there. Do it on the next tick with `horizon.after(1, ...)`, as the join above does, and as
the nickname below does.

Some callbacks run in the middle of an event and can't reach the world at all, such as `on_hurt` and `on_chat`.
There the player is only `id` and `kind`, or only `uuid` and `name`.

## Saved data, a nickname and the chat

When a player feeds an example mob, mob.lua counts it in `player:data()`. At three feedings, the player gets a
nickname. The chat callback can't read saved data, so mob.lua also adds the player to a set that the chat callback
can read:

```lua
    local mine = player:data()
    if mine then
      mine.fed = (mine.fed or 0) + 1
      if mine.fed >= 3 then
        Players.keepers[player.uuid] = true
      end
      if mine.fed == 3 then
        local name = player.name
        horizon.after(1, function()
          local p = horizon.player(name)
          if p then
            modkit.player(p):nickname(name .. " the Keeper")
          end
        end)
        horizon.log(("EXAMPLE keeper: %s fed three example mobs"):format(player.name))
      end
    end
```

The chat callback answers `ping`, and tells a keeper that they keep example mobs. The bed callback keeps players out of bed
while example mobs roam. A cancel ends the dispatch, so another mod's `on_sleep` is not called:

```lua
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
```

## See it in the game

- Join a world. You see a title, and get a feather on your first visit.
- Type `ping` in the chat.
- Break a block, and die.
- Feed three example mobs, then chat.
- Try a bed at night with an example mob nearby.
