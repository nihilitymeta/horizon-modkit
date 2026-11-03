-- Example Mod: what it does, one file per concept under scripts/example/,
-- each with a comment on what it shows and how to see it in game (the guides
-- in docs/guides/ point at them; docs/api.md is the reference). This file
-- runs at start and on /reload and requires the rest; what the mod adds is
-- scripts/registry.lua.
require("@example/mod")
require("@example/item")
require("@example/block")
require("@example/mob")
require("@example/players")
require("@example/command")
require("@example/timers_and_data")
require("@example/spawning")
require("@example/effects")
