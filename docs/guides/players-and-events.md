# Players and events

What every player does reaches one class, `M:players()`, with a callback per event. Example:
[scripts/example/players.lua](../../examples/example_mod/scripts/example/players.lua). Reference:
[api.md, Players](../api.md#players-mplayers-and-the-player).

```lua
local Players = M:players()

-- Joined: a title with the greeting from the settings, a visit counted in
-- the player's own saved table, a feather on the first visit. A give to a
-- player from inside their own join is done next tick, from a timer, where
-- every player is reachable.
function Players:on_join(player)
  modkit.title(player, cfg.greeting, "Example Mod on modkit " .. modkit.VERSION)
  local mine = player:data()
  if mine then
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
a give to someone else does nothing there. Do it next tick from `horizon.after(1, ...)`, as the join above does.
Some callbacks come mid-event with no world at hand (`on_hurt`, `on_chat`): the player is `id` and `kind`, or
`uuid` and `name`, and nothing else.

See it in game: join (a title, a feather the first time), say `ping` in the chat, break a block, die.
