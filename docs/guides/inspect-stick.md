# The inspect stick

The inspect stick shows what the game knows about an entity or a block while your mod runs. Right-click something with
it, and a window opens over the world with its data. It works like vanilla's debug stick, and comes with the modkit.

## Get one

1. Play in creative, with cheats on (single player) or operator level 2 (a server).
2. Type `/give @s horizon_modkit:inspect_stick`.

The stick is not in a creative tab and has no recipe. In survival, or without the permission, it is a plain stick.

## Use it

| Right-click | Shows |
|---|---|
| An entity | Its data, as `/data get entity` prints it |
| The same mob again | Its next page: Inspect, Goals, Senses, then Nav |
| The same mob, sneaking | The page before |
| Another entity | The same page, if it has one |
| A block | The block window |

A line over the hotbar names the page. The click does nothing else: a villager doesn't trade, a chest doesn't open
and a button isn't pressed.

The block window shows the block's state, light, biome, redstone power, random and scheduled ticks, tags, its block
entity's data, and, for a mod's block, the mod and template that declare it. Its collision boxes are drawn in blue
in the world, and its outline in yellow.

Each window has a **stop** button. A number in the Inspect window has a **watch** button that charts it over time, and
the Goals window's **log** button writes the mob's AI to a file.

## What you need

- Event Horizon, with the modkit installed. The game doesn't need `--dev-tools`.
- On a LAN world or a server, each player's windows open on their own screen. The server sends them once a second;
  a window's interval choice changes that, down to a quarter of a second.
- Press F8 to free the pointer and click the windows' buttons, and F8 again to play. To use another key, rebind
  **Free Mouse for Dev Windows** in Options → Controls → Key Binds.

The engine's [dev-tools.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/dev-tools.md#the-inspect-stick)
describes the windows in full.
