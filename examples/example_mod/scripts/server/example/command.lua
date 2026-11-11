-- Commands (guide: docs/guides/commands.md; reference: docs/api.md,
-- "The mod"). `M:command(usage, level, fn)`: the words, then
-- <name:kind> required and [name:kind] optional arguments (word, text,
-- integer, number, boolean, player, item, block_pos), the operator level
-- (0 everyone, 2 operators), and fn(player, args) with the arguments by
-- name. horizon.feedback(text) answers. Inside a player's own command only
-- that player is reached; another player is reached next tick, from a timer.
-- See it in game: /example, /example feather 3, /example lamp, /example where.
-- The other files add theirs under the same first word (nest, lure, spawn,
-- show, report, max, greeting): the tree merges them.
local modkit = require("@modkit")
local M = require("@example/mod")

M:command("example", 0, function(player, args)
  horizon.feedback(
    "/example feather [count] | lamp | nest | lure [count] | where | spawn [count] | show | report | max [limit] | greeting <text>"
  )
end)

M:command("example feather [count:integer] [to:player]", 2, function(player, args)
  local count = args.count or 1
  if args.to and args.to ~= player.name then
    local to = args.to
    horizon.after(1, function()
      local p = horizon.player(to)
      if p then
        modkit.player(p):give("example_mod:example_item", count)
      end
    end)
    horizon.feedback(("%d feather(s) sent to %s"):format(count, to))
    return
  end
  player:give("example_mod:example_item", count)
  horizon.feedback(("%d feather(s) given"):format(count))
  horizon.log(("EXAMPLE command feather by %s"):format(player.name))
end)

M:command("example lamp", 2, function(player, args)
  player:give("example_mod:example_block", 1)
  horizon.feedback("a lamp given: place it and right-click it")
end)

M:command("example where", 0, function(player, args)
  local p, t = player.position, horizon.time()
  horizon.feedback(
    ("%s is at %.0f %.0f %.0f in %s, day %d, %s"):format(
      player.name,
      p.x,
      p.y,
      p.z,
      player.dimension,
      t.day,
      t.rain and "raining" or "dry"
    )
  )
end)

return M
