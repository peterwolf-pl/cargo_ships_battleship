local function unlock(recipe)
  return {
    type = "unlock-recipe",
    recipe = recipe
  }
end

data:extend{
  {
    type = "technology",
    name = "battleship",
    icon = GRAPHICSPATH .. "technology/cargo_ships.png",
    icon_size = 256,
    effects = {
      unlock("battleship")
    },
    prerequisites = {"cargo_ships", "military-3", "artillery"},
    unit = {
      count = 250,
      ingredients = {
        {"automation-science-pack", 100},
        {"logistic-science-pack", 100},
        {"military-science-pack", 100},
        {"chemical-science-pack", 100}
      },
      time = 30
    },
    order = "c-g-a"
  }
}
