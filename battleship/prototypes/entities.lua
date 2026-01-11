local battleship_icons = {
  {
    icon = GRAPHICSPATH .. "icons/cargoship_icon.png",
    icon_size = 64,
    tint = {0.75, 0.75, 0.95}
  },
  {
    icon = "__base__/graphics/icons/artillery-turret.png",
    icon_size = 64,
    scale = 0.5,
    shift = {8, 8}
  }
}

local cargo_ship = data.raw["cargo-wagon"]["cargo_ship"]
local battleship = table.deepcopy(cargo_ship)

battleship.name = "battleship"
battleship.icons = battleship_icons
battleship.icon = nil
battleship.minable = {mining_time = 1, result = "battleship"}
battleship.max_health = 7500
battleship.inventory_size = 800

if battleship.pictures and battleship.pictures.rotated and battleship.pictures.rotated.layers then
  battleship.pictures.rotated.layers[1].tint = {0.75, 0.75, 0.95}
end

local artillery_base = table.deepcopy(data.raw["artillery-turret"]["artillery-turret"])
artillery_base.flags = {
  "placeable-off-grid",
  "not-on-map",
  "not-blueprintable",
  "not-deconstructable"
}
artillery_base.max_health = 1200
artillery_base.minable = nil
artillery_base.collision_box = {{0, 0}, {0, 0}}
artillery_base.selection_box = {{0, 0}, {0, 0}}
artillery_base.selection_priority = 0
artillery_base.order = "z[battleship-cannon]"
artillery_base.icons = battleship_icons
artillery_base.icon = nil
artillery_base.corpse = nil
artillery_base.damaged_trigger_effect = nil

local battleship_cannon_1 = table.deepcopy(artillery_base)
battleship_cannon_1.name = "battleship-cannon-1"

local battleship_cannon_2 = table.deepcopy(artillery_base)
battleship_cannon_2.name = "battleship-cannon-2"

local battleship_cannon_3 = table.deepcopy(artillery_base)
battleship_cannon_3.name = "battleship-cannon-3"

local battleship_cannon_4 = table.deepcopy(artillery_base)
battleship_cannon_4.name = "battleship-cannon-4"

data:extend{
  battleship,
  battleship_cannon_1,
  battleship_cannon_2,
  battleship_cannon_3,
  battleship_cannon_4
}
