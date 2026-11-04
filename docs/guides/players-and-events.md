# Players and events

What every player does reaches one class, `M:players()`, with a callback per event. Example:
[scripts/example/players.lua](../../examples/example_mod/scripts/example/players.lua); the keeper's count in
[scripts/example/mob.lua](../../examples/example_mod/scripts/example/mob.lua). Reference:
[api.md, Players](../api.md#players-mplayers-and-the-player).

```lua
local Players = M:players()

-- Who fed three example mobs, by uuid (scripts/example/mob.lua fills it, and
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
    if (mine.fed or 0) >= 3 then Players.keepers[player.uuid] = true end
    mine.visits = (mine.visits or 0) + 1
    if mine.visits == 1 then
      local name = player.name
      horizon.after(1, function()
        local p = horizon.player(name)
        if p then modkit.player(p):give("example_mod:example_item", 1) end
      end)
    end
    horizon.log(("EXAMPLE player joined: %s, visit %d"):format(player.name, mine.visits))
  end
end
```

**The events.** `on_join`, `on_leave`, `on_respawn`, `on_death(player, cause)` (the death message's key),
`on_break_block(player, block)` and `on_place_block(player, block, item)` (return true from the first to keep
the block), `on_pickup(player, item, count)` (return true to leave it), `on_chat(player, line)` (return a string
to send instead, true to drop it), `on_command(player, line)` (return true to stop it; `player:reply` answers),
`on_sleep(player, x, y, z)` (return true to keep them out), `on_hurt`, `on_fall`, `on_knockback`, `on_exp`,
`on_open_menu`, `on_change_dimension`, and `on_tick(player)` every tick (keep it light).

**The player** in these and in every other callback that names one is a table: `uuid`, `name`, `position`,
`dimension`, `game_mode`, `health`, `held`, and the methods `give`, `take`, `inventory`, `count`, `effect`,
`experience`, `levels`, `nickname`, `tell`, `action_bar`, `title`, `data` (the mod's saved table on them),
`raycast`, `block_below`. A player read from the world (`horizon.player(name)`) gets the methods with
`modkit.player(t)`.

**One rule to know.** Inside a player's own callback (their click, their command) only that player is reached;
a give to someone else does nothing there. Do it next tick from `horizon.after(1, ...)`, as the join above does
and as the nickname below does. Some callbacks come mid-event with no world at hand (`on_hurt`, `on_chat`): the
player is `id` and `kind`, or `uuid` and `name`, and nothing else.

**Saved data driving a name and the chat.** Feeding the example mob counts in the feeder's `player:data()`; at
three they are nicknamed, and a set the chat callback can read (it has no host for saved data) gives their lines
a suffix. The count, in mob.lua:

```lua
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
```

The chat, and a bed refused (a cancel ends the dispatch: another mod's `on_sleep` is not asked):

```lua
function Players:on_chat(player, line)
  if line == "ping" then
    horizon.log(("EXAMPLE chat from %s"):format(player.name))
    return "pong"
  end
  if Players.keepers[player.uuid] then
    horizon.log(("EXAMPLE keeper chat from %s"):format(player.name))
    return line .. " (keeper of example mobs)"
  end
  return nil
end

-- Entering a bed: return true to keep them out. No sleep while example mobs
-- roam. A cancel ends the dispatch: another mod's on_sleep is not asked.
function Players:on_sleep(player, x, y, z)
  local roaming = 0
  for _, m in ipairs(horizon.mobs()) do
    if m.kind == "example_mod:example_mob" then roaming = roaming + 1 end
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

See it in game: join (a title, a feather the first time), say `ping` in the chat, break a block, die; feed three
example mobs and chat; try a bed at night with an example mob about.
