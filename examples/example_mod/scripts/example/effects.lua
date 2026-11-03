-- Sounds, particles, titles, the action bar and status effects (guide:
-- docs/guides/sounds-and-effects.md; reference: docs/api.md, "Commands and
-- effects", and the player's methods). Each is an action from a callback
-- with a world at hand; a command has none, so they run next tick, from a
-- timer. See it in game: /example show.
local modkit = require("@modkit")
local M = require("@example/mod")

M:command("example show", 0, function(player, args)
  local name, p = player.name, player.position
  horizon.after(1, function()
    modkit.sound("minecraft:entity.player.levelup", p.x, p.y, p.z, 1.0, 1.0)
    modkit.particles("minecraft:firework", p.x, p.y + 2, p.z, 30, 1.0, 0.05)
    local raw = horizon.player(name)
    if not raw then return end
    local who = modkit.player(raw)
    who:title_times(5, 40, 10)
    who:title("Example Mod", "sounds, particles, titles, effects")
    who:action_bar("and the action bar")
    who:effect("minecraft:speed", 200, 1)
    who:effect("example_mod:example_effect", 200)
    horizon.log(("EXAMPLE effects shown to %s"):format(name))
  end)
  horizon.feedback("look up")
end)

return M
