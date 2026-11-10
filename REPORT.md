# 44-k5-modkit report

Branch: `agent/w-meta/44-k5-modkit` on `hub` (`/git/horizon-modkit.git`), from `hub/agent/lead/44-modkit-base`
(`e85d6c7`). Engine read-only at `/work/horizon` (`febfdca5f2`); built `fast` `horizon-client`,
`horizon-ctl`, `event-horizon` game binary and `cargo-horizon-mod`.

## Summary

The modkit now speaks only the native Lua hooks: one event table per handler, native names, kind filters where
the signature takes one. Every legacy `horizon.on` name and every dead helper call is gone; the example mod,
all four probes, the coverage drive and the docs moved with it. All checks exit 0; hook-coverage drives 49
hooks and 24 modkit callbacks with no script errors, and the new HUD check proves both draw hooks fire
offscreen.

## Size

About 1500 changed lines, not counting the regenerated types (921 of them are the copy of the engine's
generated `docs/api/horizon.d.lua`): `scripts/modkit` +250/−147, `scripts/init.lua` +34/−14, `examples` +59/−32,
`tools` +85/−74, `docs` +136/−91, `types` +921/−66, plus 189 lines of new files (`scripts/modkit/held.lua`,
`docs/migrating-to-native-hooks.md`, `tools/hud-check.sh`, `tools/hud-probe/`). The types copy dominates;
hand-written change is ~600 lines.

## Every old hook → new hook change

Library (`scripts/modkit/`):

| Old surface | New surface |
|---|---|
| `block.lua` `random_tick(dimension, _, x, y, z, props, data)` | `random_tick(event)`: `event.dimension/pos/state_props/data`, kind `id` |
| `block.lua` `tick_block(...)` | `tick_block(event)`, same field mapping |
| `block.lua` `block_entity_tick(dimension, _, x, y, z, data)` | `block_entity_tick(event)`: `event.entity.data`, kind `id` |
| `block.lua` `block_broken(x, y, z, _, player)` kind `id` | `destroy_block(event)` bare, `event.state == id` kept in Lua; dimension via `horizon.time()`, player via `players()[1]` |
| `block.lua` `block_placed(x, y, z, _, player, item)` kind `id` | `place_block(event)` bare, `event.state == id` kept in Lua; `item` is `event.stack` |
| `block.lua` `loot_drops(source, drops)` kind `id` | `loot_drops(event)` kind `id`; `event.block` guarded, `event` passed as `source` (`source.entity` was `source.mob`) |
| `block.lua` `right_click_block(x, y, z, id, face, player, held, data)` | `right_click_block(event)` bare; id re-read with `horizon.block`, player `players()[1]`, held from `held.lua`, `data` nil |
| `entity.lua` `mob_spawned(dimension, kind, x, y, z, natural)` | `mob_spawned(event)`; adaptor rebuilds `{dimension, kind, x, y, z, natural}` so `on_spawned` is unchanged |
| `entity.lua` `mob_tick(dimension, mob, data)` | `entity_tick_post(event)`; view resolved with `horizon.mob`, `data` nil |
| `entity.lua` `mob_hurt(mob, ...)` | `living_incoming_damage(event)` kind `id`; `set_amount` assigns `event.amount` |
| `entity.lua` `mob_died(dimension, mob, cause, data)` | `mob_died(event)`; `cause.player` is a uuid or nil |
| `entity.lua` `mob_interact(dimension, mob, player, held, data)` | `interact_entity(event)` kind `id`; view resolved, player `players()[1]`, held mapped from `event.stack` |
| `entity.lua` `mob_fall` / `mob_knockback` | `living_fall` / `living_knockback` kind `id`; setters assign event fields, `x/z` written back |
| `entity.lua` `mob_equipped(mob, slot, from, to)` | `living_equipment_change(event)`; `from`/`to` are full item tables now |
| `entity.lua` `loot_drops` (`source.mob`) | `loot_drops(event)`; `Mob.host(event.entity, ...)` |
| `entity.lua` `mob_ai_register(mob)` | `mob_ai_register(event)` → `event.mob` |
| `item.lua` `item_use(item, player)` kind `id` | `use_item(event)` bare, `event.stack.id == id` kept in Lua |
| `item.lua` `item_use_on(item, player, block, face)` | `use_item_on(event)` bare; block re-read with `horizon.block` |
| `item.lua` `item_hit(item, player, target)` kind = held id | `attack_entity(event)` bare + `held.lua` selected-slot check; `target` gains `position` |
| `item.lua` `item_finished` → `set_result` | `living_entity_use_item_finish(event)` bare, player's own (`entity == nil`); `event.result = {id, count}` |
| `item.lua` `item_tick(item, player, slot, selected)` kind `id` | `inventory_tick(event)` bare → `on_tick(slot, selected)` (reduced, see below) |
| `item.lua` `item_crafted(player, recipe, item)` | `item_crafted(event)` bare, `event.stack.id` filter; player resolved from `event.player` uuid |
| `item.lua` `item_dropped(player, item, count)` | `item_dropped(event)` bare, `event.item` filter; same player resolution |
| `item.lua` `item_hurt_enemy(item, player, target)` | `hurt_enemy(event)` bare, `event.stack.id` filter |
| `item.lua` `item_use_start` → `set_duration` | `living_entity_use_item_start(event)` bare, player's own; `event.duration = n` |
| `players.lua` `player_joined/left/respawned(player)` | `player_logged_in/out`, `player_respawned(event)` → `event.player` |
| `players.lua` `player_died(player, cause)` | `player_died(event)` → `on_death(uuid, cause)`; name resolved with `horizon.player` where held |
| `players.lua` `block_broken/block_placed` | `destroy_block` / `place_block(event)` bare; player `players()[1]` |
| `players.lua` `item_picked_up(player, item, count)` | `item_picked_up(event)`; player resolved from uuid |
| `players.lua` `player_tick(player)` | `player_tick(event)` (empty) → `acting()` once per fire |
| `players.lua` `player_hurt/fall/knockback` | `living_incoming_damage/fall/knockback` kind `minecraft:player`; `{id, kind}`; setters assign fields |
| `players.lua` `player_chat(player, line)` + `horizon.reply` | `player_chat(event)`; `{uuid, name}` built; string return → `event.replies = {r}` |
| `players.lua` `player_command` + `horizon.reply` | `player_command(event)`; `player.reply` appends to `event.replies` |
| `players.lua` `player_changed_dimension/bed_enter/exp_change/container_open` | new names; `bed_enter` pos always present; `exp_change` return → `event.amount` |
| `scripts/init.lua` (inspect stick) | `right_click_block` unchanged shape use, `interact_entity` with `event.stack` hand gate; `dev.inspect` takes the uuid text |
| `modkit/init.lua` `M:on` docs | new names in the examples (`explosion_detonate`, `entity_join_level`, `projectile_launch`, `living_heal`) |
| `types/horizon.d.lua` | refreshed by copy from the engine's generated file (check.sh proves equality) |

Probes, tools, docs: `hook-probe` rewritten to new names (bare where the hook takes no kind, `register_goals` and
`player_item_held` added); `step-probe` and `modkit-probe` rewritten the same way (`M:on` names updated);
`hook-coverage.sh` asserts the 49 driven hooks by new name and lists the rest as "not driven" (informational);
`hook-coverage.sh`/`steps-check.sh`/`check.sh` also load `hud-probe`; `docs-check` passes; new
`docs/migrating-to-native-hooks.md` for modkit users; `api.md` and guides updated to the new shapes.

## Reduced or lost modkit features (all documented, none need the lead)

- Per-mob saved data is gone: the example's feeding count and the nest's meal guard moved to `world_data()`
  keyed by id/pos. `mob.data` reads nil.
- `I:on_tick(item, player, slot, selected)` is now `on_tick(slot, selected)`: the ticking stack and its player
  are not on the event.
- `P:on_death(player, cause)` is now `on_death(uuid, cause)`: the dead player has no recoverable name.
- `B:on_use`/`on_break`/`on_place` and the break/place/tick player callbacks see the first player of
  `horizon.players()` and, for `on_use`/`on_hit`, the tracked selected stack. Exact on multiplayer with
  several players on: the engine names no acting player.
- `block:set` drops (with a warning) in a click's host: `B:on_use` uses `block:replace`. The new block starts
  with its default data.
- `on_command` players: only `reply` reaches anyone; `on_chat` players stay `{uuid, name}` with no host reads.

## Checks (in order, one at a time; game dirs under `/work`, recipe as tasked)

| Check | Exit | Tail |
|---|---|---|
| `tools/check.sh --self-test` | 0 | all six mods `ok`, types equal, unknown-hook/luau/version/content refusals `ok` |
| `tools/docs-check.sh` | 0 | `docs-check: ok, every link resolves and every Lua block is lifted from a file that runs` |
| `tools/scaffold-check.sh` | 0 | `SCAFFOLD OK: my_wand loaded, the wand used, its on_use seen` |
| `tools/steps-check.sh` | 0 | `STEPS OK: 27 steps seen` (TARDIS aside verified) |
| `tools/example-check.sh` (rerun once) | 0 | `EXAMPLE OK: every concept seen`; lamp state `lit=true` right after the click |
| `tools/stick-check.sh` | 0 | `STICK OK` (all 12 lines `ok`; the known #37 button failure does not reproduce) |
| `tools/hook-coverage.sh` | 0 | 49 of 49 driven hooks fired, 24 of 24 modkit callbacks ran, 0 script errors |
| `tools/hud-check.sh` (new) | 0 | `HUD OK: both draw hooks ran and their draw calls were accepted` |

First `example-check` run failed on two lines: my `attack_entity` target lacked `position` (fixed in
`item.lua`), and the nest-mature line lost the random-tick race the task notes (passed on rerun). First
`stick-check` run failed the mob pages off by one: both hands' `interact_entity` called `dev.inspect` across
a tick boundary; fixed with the `event.stack` hand gate, now `STICK OK`.

What the HUD check proves: `tools/hud-probe` drew a rect and text on `hud` and `gui_layer_post` in an
offscreen game; both handlers logged (`hud=1 gui_layer_post=1`, layer `minecraft:crosshair`) and no game-log
error names the probe, so the batch draws were accepted. Offscreen rendering does tick the draw hooks.

## Engine bugs found

None that block. One doc-vs-behavior note filed in the task dir (`QUESTIONS.md`, uncommitted): `hook-points.md`
says `player_changed_dimension` reports "on a dedicated server only", but it fires on the single-player server
thread in both `steps-check.sh` and `hook-coverage.sh`. Code wins; the modkit drives it.

Where the task text and the engine disagree, the code wins: 59 hooks (of 516) reach Lua by a filled Lua cell,
not 448; the two declaration-served hooks are reported separately; `dedicated_only` is empty.

## Left undone

- The reference's remaining Lua hooks (`item_picked_up`, `living_equipment_listened`, `entity_tick_listened`,
  `experience_orb_pickup_listened`, `player_render_listened`, `hears_projectile_impacts`, `command`,
  `hud`/`gui_layer_post` outside the probe) are reported "not driven", not driven: no drive exists for them.
- `docs-check.sh` still prints `UNCHECKED docs/guides/models-and-animation.md` (pre-existing: no example file
  linked; exit still 0).
- Mutation test: appending `horizon.on("mob_hurt", ...)` to the probe makes `tools/check.sh` exit 1 with
  `runtime error: horizon.on("mob_hurt"): no such hook` naming `scripts/init.lua:46`; reverted afterwards.
