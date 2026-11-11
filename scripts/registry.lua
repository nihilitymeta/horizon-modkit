-- The modkit's own content: the inspect stick, a developer's item like
-- vanilla's debug stick. Right-click an entity or a block with it, in
-- creative with cheats (permission 2), and the game's inspect windows open on
-- it (scripts/server/init.lua). Its template is the debug stick, so it looks like
-- one and is listed only where operator items are: get it with
-- /give @s horizon_modkit:inspect_stick.
registry.item("inspect_stick", { template = "minecraft:debug_stick" })
registry.asset("items/inspect_stick", { model = { type = "minecraft:model", model = "minecraft:item/debug_stick" } })
registry.lang("en_us", { ["item.horizon_modkit.inspect_stick"] = "Inspect Stick" })
