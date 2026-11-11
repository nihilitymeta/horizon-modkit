---
name: Dev feature
about: A tool for people making mods with the modkit (an item, a command, a screen) that only exists in a dev game
title: "Dev feature: "
labels: dev-feature-request
---

## What it is

<!-- One or two sentences: what a modder gets, and the problem it saves them from. -->

## How a modder uses it

<!-- The steps in game, and the Lua a mod writes (if any). Keep it to what someone types or clicks. -->

```lua
-- example use
```

## When it exists

<!-- Dev-only features must say how they are kept out of a normal game. -->

- [ ] Only with `--dev-tools` (or `HORIZON_DEV_TOOLS=1`)
- [ ] Only for the world's owner (the host); guests are refused
- [ ] Other: 

What a player sees without it: <!-- e.g. the item is missing from the creative tab, the command is unknown -->

## Where it lives

| Piece | Where | New or existing |
|---|---|---|
| Modkit API (`scripts/server/modkit/…`) | horizon-modkit | |
| Engine binding (`horizon.*`), if any | Event Horizon, `lua_mods` | |
| Engine screen or command it reuses | Event Horizon, `dev_tools` | |

<!-- If it needs an engine change, say what it changes in Event Horizon and why it can't be done in Lua. -->

## Done when

- [ ] `tools/check.sh --self-test` passes (with `RESOURCES` set)
- [ ] The example mod uses it, and `tools/example-check.sh` checks it in game
- [ ] `types/horizon.d.lua` copied from the engine if a binding changed; `cargo horizon-mod check` clean
- [ ] Docs: the API reference (`docs/api.md`) and a guide section, GNOME style
- [ ] Without `--dev-tools`, nothing of it shows up (checked in game)

## Not in this issue

<!-- What it deliberately does not do, and follow-ups. -->

## Open questions

<!-- Decisions still to make. -->
