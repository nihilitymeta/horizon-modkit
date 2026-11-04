# Sounds and Effects

A mod can play sounds and show particles in the world, put words on a player's screen, and give status effects to
a player or a mob.

The example comes from [scripts/example/effects.lua](../../examples/example_mod/scripts/example/effects.lua). The
reference is [the modkit table](../api.md#the-modkit-table) and the player's [messages](../api.md#messages).

This command shows the player one of each:

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

## In the world

- `modkit.sound(name, x, y, z, volume, pitch)` plays a sound for the players in range.
- `modkit.particles(name, x, y, z, count, spread, speed)` shows particles to the players near.

The names are vanilla's, such as `minecraft:entity.zombie.infect` and `minecraft:crimson_spore`. The
[ids reference](../reference/ids.md#sounds-and-particles) lists some that are known to work.

## On a screen

| Function | Where the text shows |
|---|---|
| `player:tell(text)` | in the chat |
| `player:action_bar(text)` | over the hotbar |
| `player:title(text, subtitle)` | across the screen; `player:title_times(fade_in, stay, fade_out)` sets the timing |
| `horizon.broadcast(line)` | in every player's chat |

`modkit.title`, `modkit.tell` and `modkit.action_bar` do the same, and take a player table or a name.

## Status effects

`player:effect(name, ticks, amplifier)` and `mob:effect(...)` give an effect as `/effect give` does. The defaults
are 200 ticks and amplifier 0; -1 ticks lasts for ever. `modkit.effect(target, ...)` takes a mob's id or a player's
name.

A mod can declare an effect of its own with `registry.mob_effect`, a category and a colour. Such an effect does
nothing by itself; your scripts give it meaning.

## Where they work

Each of these is an action, so it needs a callback with the world at hand, such as a mob's tick, a block's tick, an
item's use or a timer. A command queues them for the next tick, as the example does.

## See it in the game

Type `/example show`.
