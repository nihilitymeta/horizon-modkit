# Testing a Mod

This page explains how to see a mod working in the game, and describes the scripts that check the modkit and the
example mod automatically.

To test a mod, run Event Horizon's `engine-work` build with `--dev-tools`, a `--dev-mod` for the modkit and one for your
mod ([getting started](getting-started.md)). `--game-dir` sets where saves, options and logs go. `--dev-mod` reads a
mod folder as it is and keeps the mod on.

A mod's scripts live in `scripts/server/`, `scripts/client/` and `scripts/shared/`: the server's state, the window's
state, and the modules either may require. Each side starts at its folder's `init.lua`, and a state registers only
its own side's hooks. `scripts/registry.lua` and `scripts/registry/` declare content once, when the game starts; the
modkit is server-side code.

The check scripts turn the master volume off in the game folder's options before they start the game, because the
game has no mute option. If you play in that game folder afterwards, turn the volume back up in the game's options.

## What to look for

### The log

The log is `<game dir>/logs/latest.log`.

- When the world opens, it says `Horizon: Lua mod example_mod running from …`.
- A script error appears as `[lua:<mod id>] …`, with its file and line.
- Lines that a script broadcasts appear as plain `INFO` lines.

Nothing logged while the scripts first load appears, because the log is not open yet ([FAQ](reference/faq.md)).

### The example mod

Type `/example` to list the example mod's commands. Each file in
[examples/example_mod](../examples/example_mod) starts with a comment that says how to see its concept.

To see the example mob:

1. Type `/summon example_mod:example_mob`. It comes to you, eats wheat, shrugs off fire and lands softly. Three
  feedings make you its keeper, by name.
2. Type `/summon zombie` next to it, and wait three seconds. The zombie becomes an example mob.
3. Type `/goals @e[type=zombie,sort=nearest,limit=1]` to list the zombie's goals, including
  `example_mod:zombie.succumb` and `zombie.stalk`. `/nav` with the same selector draws the path it walks.

To see the nest:

1. Type `/setblock ~ ~ ~2 example_mod:example_nest`.
2. Use bone meal on it. Its stage changes to `growing`, and you keep the bone meal.
3. Type `/gamerule random_tick_speed 300`. Within seconds the nest grows to `mature`.
4. A mature nest charges up, and breeds an example mob every 400 ticks. `/data get block` shows its `charge` and
  `bred` counts.

### Hooks and the console

- Event Horizon's generated
  [hook-points.md](https://github.com/nihilitymeta/horizon/blob/engine-work/docs/api/hook-points.md) lists the
  engine hook behind each callback, and every other hook a script could listen to.
- `/lua` opens the console. Press F8 to free the mouse. The console's first section lists each mod with its
  handlers, goals and last error, with a button that reloads the mod. `print` and `horizon.log` lines appear there
  too.

## Checking scripts without a game

`cargo horizon-mod check <mod folder> --game <horizon-client> --dev-mod <horizon-modkit>` loads a scripted mod's
scripts in the game's Lua runtime, with no world. Build it in Event Horizon with `cargo build -p cargo-horizon-mod`. It
names the file and line of each problem, and exits with code 1:

- a script that fails to load
- a hook that `horizon.on` does not know
- a command that fails when it is declared

Add `--resources <26.3 folder>`, the prepared vanilla folder, and it also layers your mod's data on it as the game
does at start. A file the game would refuse fails the check here. In a game, such a file leaves every content mod out
of the world: an `add_spawns` spawner with `min_count` instead of NeoForge's `minCount`, for example.

`tools/check.sh` runs this check on the modkit, the example mod and the probes under `tools/`. Each run also
runs the script steps: StyLua formatting, selene linting and type analysis against `types/horizon.d.lua` with a
pinned luau-lsp the check downloads on the first run, so nothing needs to be on your `PATH` (`--offline` skips the
type step). With `--self-test`, it shows a misspelled hook being refused with its line, and a type error that still
loads being caught. Set `RESOURCES` to the 26.3 folder and it passes `--resources` to every check, and the self-test
also shows a misnamed spawner field being refused. The in-game checks below run all of this before they start the
game.

## Driving the game from a script

`horizon-ctl` starts the game and drives it from a shell, without a window if you want. It is built with the game,
with `-p horizon-client-lib`. Event Horizon's
[horizon-ctl-commands.md](https://github.com/nihilitymeta/horizon/blob/engine-work/docs/horizon-ctl-commands.md)
lists every command.

```sh
CTL="target/fast/horizon-ctl --socket /tmp/horizon.sock"
$CTL launch --game target/fast/horizon-client --wait --game-dir ~/horizon-dev --resources <26.3 folder> \
  --world "New World" --offscreen --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my-mod
$CTL wait-ready 180
$CTL command "summon example_mod:example_mob ~ ~ ~2"
$CTL entities 16 example_mod:example_mob
$CTL screenshot shot.png
$CTL quit
```

Run these lines from bash. zsh does not split `$CTL` into words.

Some details to keep in mind:

- `command` runs a command as the console. To run a command as the player, so that `P:on_command` sees it, use
  `chat "/cmd"`.
- `select` takes a full item id, and reaches the hotbar only.
- A bed needs a player at night, with no monster within eight blocks.
- `right_click_block` runs once for each hand.
- When `HORIZON_HOME` is set, the game writes `logs/` there. The scripts set it to the game folder, so the log is
  where they expect it.

## The check scripts

The scripts below each start the game, drive it, and read the log. They take the same variables:

```sh
HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/example-check.sh
```

| Variable | What it is |
|---|---|
| `HORIZON` | a built checkout of Event Horizon |
| `RESOURCES` | the game's 26.3 resources folder |
| `GAME_DIR` | the game folder to use |

`tools/steps-check.sh` and `tools/hook-coverage.sh` open a fresh `modkit-check` world on each run.
`tools/example-check.sh` opens the world named by `WORLD`, which is `New World` by default. `tools/hud-check.sh`
opens a `hud-check` world with `tools/hud-probe`.

### Every concept of the example mod

`tools/example-check.sh` plays the example mod through every concept, and expects each file's `EXAMPLE ...` line:
the feather, the lamp, the mob, the keeper, the conversion, the lure, the nest, the chat, the commands, the effects,
the timer, the settings file, the refused bed, the cull and a death. For the nest, it checks growing, breeding,
being spent, refusing a bare hand, and breaking with a hoe.

Before it starts, it writes `config/example_mod.json` in the game folder, with a nest that breeds once.

### One result for each part of the API

`tools/steps-check.sh` runs one session with `tools/step-probe` next to the example mod. It shows each part of the
Lua API working on the build at hand:

- The reads and a raycast when the player joins.
- An item callback, the lure.
- Deaths, and the name at join.
- A timer, and the world and player data across two launches.
- A command that plays a sound and shows particles and a title.
- The spawn egg, and a screenshot of the mob.
- The world and player functions: setting a block, filling a box, a falling block, a dropped item, items given to
  and taken from a named player, effects, experience, a nickname, a console command, and the settings file written
  at load.
- The example mod's use of them: feeding an example mob, `/example max`, a spent nest turning to sculk, a soft
  landing, and the refused bed.
- Every modkit callback, through `tools/modkit-probe`.
- Natural spawning: an example mob that the biome modifier adds, either generated with the world's chunks or
  spawned at midnight.

Before it starts, it writes `config/example_mod.json`, with a nest that breeds once.

### The driven hooks, and every modkit callback

`tools/hook-coverage.sh` reads Event Horizon's generated
[hook reference](https://github.com/nihilitymeta/horizon/blob/engine-work/docs/api/hook-points.md), which lists every
hook that reaches Lua: far more than any drive can exercise. It runs the game with `tools/hook-probe`, a mod with
one logging handler for each hook the drive reaches, next to the example mod. Then it drives the game through each
of those hooks: blocks, mobs, items, a command, `/reload`, a death, a fall, a snowball, a dropped stick, crafted
planks, a chest and a bed, an orb, a hurt and a heal, an armed zombie, and TNT. A driven hook that did not fire
fails the check. The hooks outside the driven set are reported as "not driven", which is informational, not a
failure. The check also reports any script error.

`tools/modkit-probe` runs alongside. It defines every modkit callback of those hooks, as a mod writes them, and logs
once when each runs. The check expects all of them.

Two details make the drive reliable:

- The example mod cancels `on_sleep` while example mobs roam, and a cancel stops the other mods from hearing the
  hook. So the check drives the bed with no example mob alive.
- The game checks for night before it calls the bed hook, and a saved world's time drifts between runs. So the
  check sets the time to night first.

Run it after an engine change, or after adding a hook.

`/reload` logs `content mods not loaded: example_mod: ... is already a block` for a mod that registers a block. This
message is harmless and known (nihilitymeta/horizon#15).

### The draw hooks

`tools/hud-check.sh` starts a game with `tools/hud-probe`, which draws a rect and a line of text on the `hud` and
`gui_layer_post` hooks. The check polls the log until both handlers logged after their draws, and fails on any
`[lua:hud_probe]` line at WARN or ERROR. An offscreen run that never draws fails: drive the probe in a window with
`--dev-mod tools/hud-probe` first, then point the check at that game dir's log.

### The capability gates, the world writes and the client draws

`tools/gates-check.sh` starts one game with the three mods under `tools/gates-probe/` and shows the engine's
capability gates working in a game, not only in the Lua test harness:

- `gates_denied` declares only `scripts`: each helper that needs `world-settings` or `server-admin` is called and
  must fail, naming the helper and the capability, with nothing changed.
- `gates_allowed` declares both capabilities: a `keep_inventory` write, a day-time write and a `sidebar` display
  slot must take effect, a rule off the allow-list and a wrong-kind value must still be refused, a cancelled `every`
  must stop on its second firing, and a kick of a name nobody has is a no-op.
- `gates_client` adds one icon marker and draws one world primitive; both calls must be accepted.

Each fact is one `GATE` line in the log, and the check requires each of them, the day-time line included: a missing
line prints `FAILED: no line: …`. A `GATE … BAD` line, an `[lua:gates_*]` line at WARN or ERROR, or a denied write
that changed the day clock, the game mode or the rule fails the run too.

The control socket sits in the game dir (`$GAME_DIR/ctl.sock`), and the check quits the game it started on every
exit, a Ctrl-C included, by the pid the launch reported; the socket is removed. No game and no socket file is left
behind. A game dir longer than the unix socket path limit (about 100 bytes) falls back to
`/tmp/horizon-gates-check.sock`, and the check says so.

## Playing through the launcher

To play through the launcher instead, install the build as a launcher version: run Event Horizon's
`tools/deploy_local_mac.sh` on macOS, or `tools/deploy_test_launcher.sh` on Linux. Then add
`--dev-tools --dev-mod …` to the launcher's `settings.json` as `game_args`.
