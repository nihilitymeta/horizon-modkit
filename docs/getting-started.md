# Getting started

From nothing to an item of your own in the game, in ten minutes. You need the fork's `engine-work` build
([building it](https://github.com/whos-carmen/horizon/blob/engine-work/docs/building.md)), its `cargo-horizon-mod`
(`cargo build -p cargo-horizon-mod` there), and this repo cloned beside where your mod will live.

## 1. Scaffold

```sh
cargo horizon-mod new my-mod --template lua --name "My Mod"
```

That writes `horizon-mod.toml` (the manifest: `capabilities = ["registries", "scripts"]`,
`depends = ["horizon_modkit >= 0.7"]`), `scripts/registry.lua` (a wand, a stick by template),
`scripts/init.lua` (its `on_use`), a lang file, a `.luaurc` that points an editor at this repo, and a README.

## 2. Run

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my-mod
```

Open a world, `/give @s my_mod:wand`, right-click: everyone is told you waved it, sparks rise where you stand.
The scaffold's `scripts/init.lua` is all of it:

```lua
local modkit = require("@modkit")
local M = modkit.mod("my_mod")

-- A right click with the wand, in the air or on a block: a word to everyone,
-- sparks where the player stands. Return true and the click is taken
-- (nothing else acts on it).
local Wand = M:item("wand")
function Wand:on_use(item, player)
  local p = player.position
  horizon.broadcast(("%s waves the wand"):format(player.name))
  modkit.particles("minecraft:happy_villager", p.x, p.y + 1, p.z, 12, 0.5, 0.05)
  return true
end
```

## 3. Edit

Change the message, save, type `/reload` in the game: the scripts run again. Adding an item, block or entity
type in `scripts/registry.lua` needs the game restarted ([reload and restart](guides/reload-and-restart.md)).

## 4. Check without a game

```sh
cargo horizon-mod check . --game /path/to/horizon-client --dev-mod /path/to/horizon-modkit
luau-lsp analyze --definitions @horizon=/path/to/horizon-modkit/types/horizon.d.lua --platform=standard scripts
```

The first loads your scripts in the game's Lua runtime and says which file and line fails; the second, with
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) installed, marks a misspelled function or hook, and in
an editor completes the API ([in an editor](api.md#in-an-editor)).

## 5. Read on

The [example mod](../examples/example_mod) has one file per concept; each [guide](../README.md#guides) is
one screen about one of them, and [api.md](api.md) is the reference. `/example` in a game with the example
mod loaded lists what it can show you.
