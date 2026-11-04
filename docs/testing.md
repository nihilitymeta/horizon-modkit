# Testing a mod in game

The game is the fork's `engine-work` build run with `--dev-tools` and a `--dev-mod` for the modkit and one for the
mod ([getting started](getting-started.md)). `--game-dir` is where saves, options and logs go; `--dev-mod` reads a
mod folder as it is and keeps it on. The check scripts below turn the master volume off in the game dir's options
before they launch (the game has no mute flag), so a check runs silent; turn it back up in the game's options when
playing there.

## What to see

- The log (`<game dir>/logs/latest.log`) says `Horizon: Lua mod example_mod running from …` when the world opens;
  a script error is logged with its file and line as `[lua:<mod id>] …`. Lines a script broadcasts are plain
  `INFO` lines there. Nothing logged at load shows: the log is not open yet ([FAQ](reference/faq.md)).
- `/example` lists the example mod's commands; each file of
  [examples/example_mod](../examples/example_mod) starts with a comment that says how to see its concept.
- `/summon example_mod:example_mob`: it comes to you, eats wheat (three feedings make you its keeper, by name),
  shrugs fire off, lands softly. `/summon zombie` beside it and wait three seconds: the zombie becomes one.
  `/goals @e[type=zombie,sort=nearest,limit=1]` lists `example_mod:zombie.succumb` and `zombie.stalk`; `/nav`
  on the same selector draws the path it walks.
- `/setblock ~ ~ ~2 example_mod:example_nest`, then bone meal on it: the stage goes to `growing` and the bone meal
  is kept. `/gamerule random_tick_speed 300` grows it to `mature` within seconds; mature, it charges (`/data get
  block` shows `charge` and `bred`) and breeds an example mob every 400 ticks.
- Which engine hook each callback rides on, and what else a script could listen to, is the fork's generated
  [hook-points.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/api/hook-points.md).
- `/lua` opens the console (F8 frees the mouse): its first fold lists each mod with its handlers, goals and last
  error and reloads it on a click; `print` and `horizon.log` lines appear there.

## Before a game: the scripts load headlessly

`cargo horizon-mod check <mod folder> --game <horizon-client> --dev-mod <horizon-modkit>` (the fork's
`cargo-horizon-mod`, `cargo build -p cargo-horizon-mod`) loads a scripted mod's scripts in the game's Lua runtime
with no world: a script that fails to load, a hook `horizon.on` does not know, a command that errors when declared,
each with its file and line, exit code 1. `tools/check.sh` runs it on the modkit, the example mod and the three
probes under `tools/` (`--self-test` shows a misspelled hook refused with its line), and, with luau-lsp installed,
analyzes each against `types/horizon.d.lua`. The in-game checks below run both first, before launching.

## Driving it from a script

`horizon-ctl` (built with the game: `-p horizon-client-lib`) launches and drives the game from a shell, offscreen
if wanted; the fork's [horizon-ctl-commands.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/horizon-ctl-commands.md)
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

Things that bite: `command` runs on the console's path, so a player's command (`Players:on_command`) is
`chat "/cmd"`; `select` takes a full item id and reaches the hotbar only; a bed takes a player at night with no
monster within 8 blocks; `right_click_block` runs once per hand. The game writes `logs/` under `HORIZON_HOME` when
that is set: the scripts export it as the game dir, so the log is there.

## Every concept of the example mod

`tools/example-check.sh` plays the example mod through every concept and expects each file's `EXAMPLE ...` line:
the feather, the lamp, the mob, the keeper, the conversion, the lure, the nest (grown, bred, spent, kept from a
bare hand, hoed), the chat, the commands, the effects, the timer, the settings file, the bed refused, the cull, a
death. It writes `config/example_mod.json` in the game dir first, with a nest that breeds once.

```sh
HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/example-check.sh
```

## One observable per step of the modding API

`tools/steps-check.sh` runs one session with `tools/step-probe` beside the example mod and shows each part of the
Lua API working on the build at hand: the reads and a raycast at join, the lure (an item callback), the deaths and
the join name, a timer and the world and player data across launches, a command that plays a sound, particles and a
title, the spawn egg, a screenshot of the mob, and the world and player helpers (a block set and a box filled, a
falling block and a dropped item, items given to and taken from a named player, effects, experience, a nickname, a
console command, the settings file written at load); then the example mod's use of them: feeding an example mob,
`/example max`, a spent nest turning to sculk, a soft landing, the bed refused; then every modkit callback
(`tools/modkit-probe`). It writes `config/example_mod.json` first, with a nest that breeds once. The natural-spawn
step at the end is a warning, not a failure: natural spawning produced nothing at all in a fresh world on this
build, zombies included, an open engine question. Same variables as above.

## Every hook the engine lists

`tools/hook-coverage.sh` reads the fork's generated [hook reference](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/api/hook-points.md),
runs the game with `tools/hook-probe` (a mod with one logging handler per Lua hook) beside the example mod, drives
the game through each of them (blocks, mobs, items, a command, `/reload`, a death; a fall, a snowball, a dropped
stick, planks crafted, a chest and a bed, an orb, a hurt and a heal, a zombie armed, tnt) and reports the hooks that
did not fire and any script error. `tools/modkit-probe` rides along: every modkit callback of those hooks, written
as a mod writes it, logging once when it runs, and the check expects each. A hook the example mod itself cancels
(its `on_sleep` while example mobs roam) is driven with no example mob alive, since a cancel ends the dispatch
before the probes are asked; the bed is driven at night (`time set night`), since the game's own checks come before
the hook and a saved world's time drifts between runs. Run it after an engine change or a new hook:

```sh
HORIZON=/path/to/horizon RESOURCES=<26.3 folder> GAME_DIR=~/horizon-dev tools/hook-coverage.sh
```

`/reload` logs `content mods not loaded: example_mod: ... is already a block` for a mod that registers a block:
pre-existing, and harmless (whos-carmen/horizon#15).

To play through the launcher instead, install the build as a launcher version (the fork's
`tools/deploy_local_mac.sh` on macOS, `tools/deploy_test_launcher.sh` on Linux) and put `--dev-tools --dev-mod …`
in the launcher's `settings.json` as `game_args`.
