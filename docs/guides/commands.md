# Commands

`M:command(usage, level, fn)` puts a command of the mod's in the server's tree. Example:
[scripts/example/command.lua](../../examples/example_mod/scripts/example/command.lua). Reference:
[api.md, Commands and effects](../api.md#commands-and-effects).

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

**The usage string** is the words, then the arguments: `<name:kind>` required, `[name:kind]` optional, kinds
`word`, `text`, `integer`, `number`, `boolean`, `player`, `item`, `block_pos`. The game parses them and refuses a
bad one with its own message before `fn` runs; `args` has them by name. Several commands may share the first
word (`example feather`, `example lamp`): the tree merges them.

**The level** is the operator level the caller needs: 0 for everyone, 2 for operators (as `/give`), 4 for the
console. **`fn(player, args)`** runs for the caller; `horizon.feedback(text)` answers them, and only they are
reached inside it (another player next tick, from a timer, as above). A command has no world at hand for
summons or blocks either: queue those the same way ([spawning](spawning.md) does).

**From a script.** `modkit.run_command(line)` runs any command as the console does, for what the API has no
method for yet (`time set`, `weather`, `tp`, game rules), from a timer or a mob or block callback.

See it in game: `/example`, `/example feather 3`, `/example where`.
