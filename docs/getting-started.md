# Getting Started

This guide takes you from nothing to an item of your own in the game. It takes about ten minutes.

You need:

- the fork's `engine-work` build of the game
  ([building it](https://github.com/whos-carmen/horizon/blob/engine-work/docs/building.md))
- the fork's `cargo-horizon-mod`, which you build in the fork's checkout with `cargo build -p cargo-horizon-mod`
- a clone of this repository, next to the folder where your mod will live

## 1. Create the mod

```sh
cargo horizon-mod new my-mod --template lua --name "My Mod"
```

The command writes these files:

| File | What it is |
|---|---|
| `horizon-mod.toml` | the manifest, with `capabilities = ["registries", "scripts"]` and `depends = ["horizon_modkit >= 0.7"]` |
| `scripts/registry.lua` | what the mod adds: a wand, which is a stick by template |
| `scripts/init.lua` | what the mod does: the wand's `on_use` |
| `assets/my_mod/lang/en_us.json` | the wand's name |
| `.luaurc` | points your editor at the modkit checkout |
| `README.md` | how to run and build the mod |

## 2. Run it

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my-mod
```

Open a world, type `/give @s my_mod:wand`, and right-click. Everyone sees a message that you waved the wand, and
sparks rise where you stand. This is the whole of `scripts/init.lua`:

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

## 3. Change it

Change the message, save the file, and type `/reload` in the game. The scripts run again with your change.

A new item, block or entity type in `scripts/registry.lua` needs the game restarted. The
[reload and restart](guides/reload-and-restart.md) guide lists what each kind of change needs.

## 4. Check it without a game

Two commands find most mistakes before you start the game:

```sh
cargo horizon-mod check . --game /path/to/horizon-client --dev-mod /path/to/horizon-modkit
luau-lsp analyze --definitions @horizon=/path/to/horizon-modkit/types/horizon.d.lua --platform=standard scripts
```

The first command loads your scripts in the game's Lua runtime, and names the file and line of anything that fails.
The second needs [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp). It marks a misspelled function or hook
name. In an editor, luau-lsp also completes the API ([editor support](api.md#editor-support)).

## 5. Learn more

- The [example mod](../examples/example_mod) has one file for each concept.
- Each [guide](../README.md#guides) explains one concept.
- The [API reference](api.md) describes every class and callback.

With the example mod loaded, type `/example` in the game to list what it can show you.
