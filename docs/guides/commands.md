# Commands

`M:command(usage, level, fn)` adds a command of your mod to the server's command tree. The chat box completes it as
it completes vanilla's commands.

The example comes from [scripts/example/command.lua](../../examples/example_mod/scripts/example/command.lua). The
reference is [`M:command`](../api.md#mcommandusage-level-fn).

This command gives feathers to the player who typed it, or to another player:

```lua
M:command("example feather [count:integer] [to:player]", 2, function(player, args)
  local count = args.count or 1
  if args.to and args.to ~= player.name then
    local to = args.to
    horizon.after(1, function()
      local p = horizon.player(to)
      if p then modkit.player(p):give("example_mod:example_item", count) end
    end)
    horizon.feedback(("%d feather(s) sent to %s"):format(count, to))
    return
  end
  player:give("example_mod:example_item", count)
  horizon.feedback(("%d feather(s) given"):format(count))
  horizon.log(("EXAMPLE command feather by %s"):format(player.name))
end)
```

## The usage string

The usage string is the command's words, then its arguments:

- `<name:kind>` is a required argument.
- `[name:kind]` is an optional argument.

The kinds are `word`, `text`, `integer`, `number`, `boolean`, `player`, `item` and `block_pos`. The game parses the
arguments and refuses a wrong one with its own message, before `fn` runs. `args` holds the arguments by name.

Several commands can share their first word, such as `example feather` and `example lamp`. The game merges them into
one tree.

## The level

The level is the operator level a player needs to run the command:

| Level | Who |
|---|---|
| 0 | everyone |
| 2 | operators, as for `/give` |
| 4 | the server console |

## The handler

`fn(player, args)` runs for the player who typed the command. `horizon.feedback(text)` answers them.

Inside the handler, only that player is reached. To give items to another player, summon a mob or change blocks,
queue the work for the next tick with `horizon.after(1, ...)`, as the example above does. The
[spawning](spawning.md) guide does the same.

## Running a command from a script

`modkit.run_command(line)` runs any command as the server console does. Use it for what the API has no function for
yet, such as `time set`, `weather`, `tp` and game rules. Call it from a timer, or from a mob or block callback.

## See it in the game

Type `/example`, `/example feather 3` or `/example where`.
