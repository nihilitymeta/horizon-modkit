-- Example Mod: what it adds, declared once when the game starts, in modules
-- under scripts/registry/ that this file requires in order. One of each
-- kind the registry takes (an item, a block, an entity type, a mob effect, a
-- creative tab) with the data and assets beside them (a recipe, loot, a tag,
-- models, the lang file), all as Lua tables: this mod ships no JSON and no
-- PNG, its looks are vanilla's textures. Then a second block and item that
-- show more: a staged block with a block entity (the nest) and an item that
-- summons (the lure). Guides: docs/guides/items.md, blocks.md, mobs.md,
-- spawning.md. A change here or in a module needs the game restarted;
-- scripts/init.lua and the files it requires reload with /reload. Each module
-- names what it adds with registry.lang, which merges every module's names
-- into one lang file.
-- See it in game: the Example Mod tab of the creative inventory.
require("@registry/items")
require("@registry/blocks")
require("@registry/mobs")
require("@registry/effects")
require("@registry/tabs")
