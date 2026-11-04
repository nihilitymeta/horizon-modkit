-- A block of its own, for the block entity hooks (a stone look, no texture of its own).
registry.block("probe", { template = "minecraft:stone", item = false })
registry.asset("blockstates/probe", { variants = { [""] = { model = "minecraft:block/stone" } } })
