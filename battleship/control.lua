local BATTLESHIP_NTH_TICK = 10
local BATTLESHIP_NAME = "battleship"
local INDEP_BATTLESHIP_NAME = "indep-battleship"
local turret_names = {
  "battleship-cannon-1",
  "battleship-cannon-2",
  "battleship-cannon-3",
  "battleship-cannon-4",
}
local turret_offsets = {
  {x = 0, y = -6.2},
  {x = 0, y = -2.1},
  {x = 0, y = 2.1},
  {x = 0, y = 6.2},
}

local function rotate_offset(offset, orientation)
  local angle = orientation * 2 * math.pi
  local cos_angle = math.cos(angle)
  local sin_angle = math.sin(angle)
  return {
    x = offset.x * cos_angle - offset.y * sin_angle,
    y = offset.x * sin_angle + offset.y * cos_angle,
  }
end

local function ensure_globals()
  storage.battleships = storage.battleships or {}
end

local function register_battleship()
  if remote.interfaces["cargo-ships"] and remote.interfaces["cargo-ships"].add_ship then
    remote.call("cargo-ships", "add_ship", {
      name = BATTLESHIP_NAME,
      engine = "cargo_ship_engine",
      engine_scale = 1,
      engine_at_front = false,
    })
    remote.call("cargo-ships", "add_boat", {
      name = INDEP_BATTLESHIP_NAME,
      rail_version = BATTLESHIP_NAME,
    })
  end
end

local function create_turret(ship, index)
  local offset = rotate_offset(turret_offsets[index], ship.orientation)
  local turret = ship.surface.create_entity{
    name = turret_names[index],
    position = {ship.position.x + offset.x, ship.position.y + offset.y},
    force = ship.force,
    create_build_effect_smoke = false,
  }
  if turret then
    turret.operable = false
  end
  return turret
end

local function destroy_entry(entry)
  if entry and entry.turrets then
    for _, turret in pairs(entry.turrets) do
      if turret and turret.valid then
        turret.destroy()
      end
    end
  end
end

local function sync_turrets(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  entry.turrets = entry.turrets or {}
  for index = 1, #turret_offsets do
    local turret = entry.turrets[index]
    if not (turret and turret.valid) then
      turret = create_turret(ship, index)
      entry.turrets[index] = turret
    end
    if turret and turret.valid then
      local offset = rotate_offset(turret_offsets[index], ship.orientation)
      turret.teleport({ship.position.x + offset.x, ship.position.y + offset.y})
      turret.force = ship.force
    end
  end
end

local function refill_ammo(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  local cargo_inventory
  if ship.type == "car" then
    cargo_inventory = ship.get_inventory(defines.inventory.car_trunk)
  else
    cargo_inventory = ship.get_inventory(defines.inventory.cargo_wagon)
  end
  if not cargo_inventory or cargo_inventory.is_empty() then
    return
  end
  local available = cargo_inventory.get_item_count("artillery-shell")
  if available <= 0 then
    return
  end
  for _, turret in pairs(entry.turrets or {}) do
    if turret and turret.valid then
      local ammo_inventory = turret.get_inventory(defines.inventory.artillery_turret_ammo)
      if ammo_inventory and ammo_inventory.is_empty() then
        local inserted = ammo_inventory.insert{name = "artillery-shell", count = available}
        if inserted > 0 then
          cargo_inventory.remove{name = "artillery-shell", count = inserted}
          available = available - inserted
          if available <= 0 then
            return
          end
        end
      end
    end
  end
end

local function ensure_entry(ship)
  if not (ship and ship.valid) then
    return
  end
  ensure_globals()
  local entry = storage.battleships[ship.unit_number]
  if not entry then
    entry = {ship = ship, turrets = {}}
    storage.battleships[ship.unit_number] = entry
  else
    entry.ship = ship
  end
  sync_turrets(entry)
end

local function remove_ship(ship)
  if not ship then
    return
  end
  ensure_globals()
  local entry = storage.battleships[ship.unit_number]
  if entry then
    destroy_entry(entry)
    storage.battleships[ship.unit_number] = nil
  end
end

local function on_nth_tick()
  if not storage.battleships then
    return
  end
  for unit_number, entry in pairs(storage.battleships) do
    if not (entry.ship and entry.ship.valid) then
      destroy_entry(entry)
      storage.battleships[unit_number] = nil
    else
      sync_turrets(entry)
      refill_ammo(entry)
    end
  end
end

local function on_built(event)
  local entity = event.entity or event.destination
  if entity and entity.valid and (entity.name == BATTLESHIP_NAME or entity.name == INDEP_BATTLESHIP_NAME) then
    ensure_entry(entity)
  end
end

local function on_removed(event)
  local entity = event.entity
  if entity and entity.valid and (entity.name == BATTLESHIP_NAME or entity.name == INDEP_BATTLESHIP_NAME) then
    remove_ship(entity)
  end
end

local function init_existing()
  ensure_globals()
  for _, surface in pairs(game.surfaces) do
    local ships = surface.find_entities_filtered{name = {BATTLESHIP_NAME, INDEP_BATTLESHIP_NAME}}
    for _, ship in pairs(ships) do
      ensure_entry(ship)
    end
  end
end

local function init_events()
  script.on_event(defines.events.on_built_entity, on_built)
  script.on_event(defines.events.on_robot_built_entity, on_built)
  script.on_event(defines.events.script_raised_built, on_built)
  script.on_event(defines.events.script_raised_revive, on_built)
  script.on_event(defines.events.on_entity_died, on_removed)
  script.on_event(defines.events.on_player_mined_entity, on_removed)
  script.on_event(defines.events.on_robot_mined_entity, on_removed)
  script.on_event(defines.events.script_raised_destroy, on_removed)
  script.on_nth_tick(BATTLESHIP_NTH_TICK, on_nth_tick)
end

script.on_init(function()
  ensure_globals()
  register_battleship()
  init_existing()
  init_events()
end)

script.on_configuration_changed(function()
  ensure_globals()
  register_battleship()
  init_existing()
  init_events()
end)

script.on_load(function()
  init_events()
end)
