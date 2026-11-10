# Migrating a modkit mod to the native hooks

The engine's Lua hooks are now the native hooks under their native names, one event table per handler. The
modkit follows them, so a mod written with the modkit changes in the places below. The engine's own table,
[docs/lua-hook-migration.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-hook-migration.md),
maps every old hook name; its generated
[horizon.d.lua](https://github.com/whos-carmen/horizon/blob/engine-work/docs/api/horizon.d.lua) wins where they
disagree.

## Handler shapes

Every modkit callback keeps its arguments, with three exceptions:

- `I:on_tick(item, player, slot, selected)` is now `I:on_tick(slot, selected)`. The ticking stack is not on the
  event, and neither is its player.
- `P:on_death(player, cause)` is now `P:on_death(uuid, cause)`. The dead player is named by uuid only.
- `M:on` takes the native hook names below, with one event table per handler.

Everything else keeps its shape: the modkit maps the event onto the callback's arguments. `hit:set_amount(n)`
still sets the damage, `fall:cancel()` still removes the fall, a returned string still answers a chat line, and a
returned item id still sets what stays in the hand. Write the new field form (`hit.amount = n`,
`event.result = ...`) only in bare `horizon.on` handlers.

## Per-callback notes

| Callback | What changed |
|---|---|
| `E:on_tick` | `mob` is the live view read with `horizon.mob`. There is no saved table on it: keep per-mob state in `horizon.world_data()`, keyed by `mob.id`. Skipped when the mob has no live view (dead or gone). |
| `E:on_interact` | `held` is the stack in the hand being tried (main then off), or nil when that hand is empty. `player` is the first player of `horizon.players()`. Skipped when the mob has no live view (dead or gone). |
| `E:on_death` | `cause.player` is the killer's uuid text, or nil. Resolve the name with `horizon.player(cause.player)`. |
| `E:on_equip` | `mob` is only `id` and `kind`. `from` and `to` are full item tables, with `damage` and `extra`. |
| `E:on_drops`, `B:on_drops` | `source` is the event itself: `source.entity` (was `source.mob`) for a mob, `source.block` for a block. |
| `I:on_hit` | The hand is read from the selected slot. With one player on it is the hand they hit with. |
| `I:on_finished`, `I:on_use_start` | A mob's own uses reach the bare handlers too; the callback keeps the player's own. |
| `B:on_use` | The click names no block data (`block.data` is nil) and no hand: `held` is the selected stack, or nil. |
| `B:on_break`, `B:on_place`, `P:on_break_block`, `P:on_place_block`, `P:on_tick` | `player` is the first player of `horizon.players()`. |
| `P:on_chat` | `player` is only `uuid` and `name`, as before, and saved tables stay out of reach. |
| `P:on_command` | Only `player:reply(text)` answers: `give`, `tell` and the item functions reach nobody. |

## Viewless mobs

The old hooks skipped a mob with no live view; the native `interact_entity` and `entity_tick_post` still tell
it. The modkit restores the old behaviour for the view callbacks: `E:on_tick` and `E:on_interact` are skipped
when `horizon.mob(id)` is nil. The id-and-kind callbacks (`E:on_hurt`, `E:on_fall`, `E:on_knockback`,
`E:on_equip`, `E:on_death`, `E:on_drops`) keep running.

## `M:on` hook names

| Old name | New name |
|---|---|
| `explosion` | `explosion_detonate` |
| `entity_joined` | `entity_join_level` |
| `projectile_launched` | `projectile_launch` |
| `projectile_impact` | `projectile_impact` (new shape: `event.projectile`, `event.owner`, the entity or block half, `event.at`) |
| `mob_heal` | `living_heal` (takes no kind: every handler hears every entity) |
| `mob_hurt`, `player_hurt` | `living_incoming_damage` (filter in Lua, or kind `minecraft:player`) |
| `mob_fall`, `player_fall` | `living_fall` |
| `mob_knockback`, `player_knockback` | `living_knockback` |
| `command` (server-side) | `perform_command`, declared with `M:command` or `horizon.command` |

The bare `horizon.on("command", fn)` hook is now the client hook: it fires for every typed slash line before the
line reaches the server. A mod command's own handler is the declaring call's `fn(player, args)`.

## Gone with no replacement

- Per-mob saved data in mob events. Only `horizon.world_data()` and `horizon.player_data(player)` read saved
  tables.
- The event `player` table in dying, chat, craft, pickup, drop and kill events: the event carries the uuid text.
  Resolve it with `horizon.player(uuid)` where the hook has a host; in `player_died` the name is unrecoverable.
- The held item in `player_tick`, `attack_entity` and `inventory_tick`, and `set_count` from `inventory_tick`.
- The ticking player in `player_tick`: read the whole list with `horizon.players()` instead.
- `block:set` in a click: `set_block_property` runs on the tick hosts only, and a click's host drops it
  with a warning. Replace the whole block (`block:replace(id, props)`) instead; the new block starts with its
  default data.
- The dead calls `horizon.set_amount`, `set_result`, `set_duration`, `set_distance`, `set_multiplier`,
  `set_strength`, `set_count` and `horizon.reply`: each fails at the call, naming the event field that replaces
  it. In modkit callbacks the equivalent forms above keep working.
