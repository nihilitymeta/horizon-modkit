# Sounds and effects

Sounds and particles in the world, words on a player's screen, status effects on a player or a mob. Example:
[scripts/example/effects.lua](../../examples/example_mod/scripts/example/effects.lua). Reference:
[api.md, Commands and effects](../api.md#commands-and-effects) and the player's methods under
[Players](../api.md#players-mplayers-and-the-player).

```lua
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
```

**In the world.** `modkit.sound(name, x, y, z, volume, pitch)` for the players in range,
`modkit.particles(name, x, y, z, count, spread, speed)` for the players near. Names are vanilla's
(`minecraft:entity.zombie.infect`, `minecraft:crimson_spore`): [reference/ids.md](../reference/ids.md#sounds-and-particles).

**On a screen.** `player:tell(text)` in the chat, `player:action_bar(text)` over the hotbar,
`player:title(text, subtitle)` across the screen with `player:title_times(fade_in, stay, fade_out)`;
`horizon.broadcast(line)` tells everyone. `modkit.title`, `modkit.tell` and `modkit.action_bar` take a player
table or a name.

**Status effects.** `player:effect(name, ticks, amplifier)` and `mob:effect(...)` as `/effect give` gives them
(200 ticks and amplifier 0 by default, -1 forever); `modkit.effect(target, ...)` by a mob's id or a player's
name. An effect of the mod's own is a `registry.mob_effect` with a category and a colour; it does nothing on its
own, the scripts give it meaning.

**Where.** Each is an action from a callback with a world at hand (a mob's tick, a block's, an item's use, a
timer). A command has none, so the example queues them for the next tick.

See it in game: `/example show`.
