local BATTLESHIP_NTH_TICK = 5
local BATTLESHIP_NAME = "battleship"
local INDEP_BATTLESHIP_NAME = "indep-battleship"
local PATROL_BOAT_NAME = "patrol-boat"
local INDEP_PATROL_BOAT_NAME = "indep-patrol-boat"
local PATROL_TURRET_NAME = "patrol-boat-missile-turret"
local RADAR_CHART_TICKS = 60
local RADAR_RANGE_MULTIPLIER = 3
local RADAR_BASE_RANGE = 14
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
local patrol_turret_offsets = {
  {x = 0, y = 0},
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
  storage.patrol_boats = storage.patrol_boats or {}
end

local function register_ships()
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
    remote.call("cargo-ships", "add_ship", {
      name = PATROL_BOAT_NAME,
      engine = "boat_engine",
      engine_scale = 0.3,
      engine_at_front = true,
    })
    remote.call("cargo-ships", "add_boat", {
      name = INDEP_PATROL_BOAT_NAME,
      rail_version = PATROL_BOAT_NAME,
    })
  end
end

local function create_turret(ship, turret_name, offset)
  local rotated_offset = rotate_offset(offset, ship.orientation)
  local turret = ship.surface.create_entity{
    name = turret_name,
    position = {ship.position.x + rotated_offset.x, ship.position.y + rotated_offset.y},
    force = ship.force,
    create_build_effect_smoke = false,
  }
  if turret then
    turret.operable = false
  end
  return turret
end

local function destroy_turrets(entry)
  if entry and entry.turrets then
    for _, turret in pairs(entry.turrets) do
      if turret and turret.valid then
        turret.destroy()
      end
    end
  end
end

local function sync_battleship_turrets(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  entry.turrets = entry.turrets or {}
  for index = 1, #turret_offsets do
    local turret = entry.turrets[index]
    if not (turret and turret.valid) then
      turret = create_turret(ship, turret_names[index], turret_offsets[index])
      entry.turrets[index] = turret
    end
    if turret and turret.valid then
      local offset = rotate_offset(turret_offsets[index], ship.orientation)
      turret.teleport({ship.position.x + offset.x, ship.position.y + offset.y})
      turret.force = ship.force
    end
  end
end

local function chart_ship_area(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  if entry.last_chart_tick and (game.tick - entry.last_chart_tick) < RADAR_CHART_TICKS then
    return
  end
  local range = RADAR_BASE_RANGE * RADAR_RANGE_MULTIPLIER
  if range <= 0 then
    return
  end
  local position = ship.position
  ship.force.chart(ship.surface, {
    {position.x - range, position.y - range},
    {position.x + range, position.y + range},
  })
  entry.last_chart_tick = game.tick
end

local function refill_battleship_ammo(entry)
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

local function sync_patrol_turret(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  local turret = entry.turret
  if not (turret and turret.valid) then
    turret = create_turret(ship, PATROL_TURRET_NAME, patrol_turret_offsets[1])
    entry.turret = turret
  end
  if turret and turret.valid then
    local offset = rotate_offset(patrol_turret_offsets[1], ship.orientation)
    turret.teleport({ship.position.x + offset.x, ship.position.y + offset.y})
    turret.force = ship.force
  end
end

local function refill_patrol_ammo(entry)
  local ship = entry.ship
  if not (ship and ship.valid) then
    return
  end
  local turret = entry.turret
  if not (turret and turret.valid) then
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
  local ammo_inventory = turret.get_inventory(defines.inventory.turret_ammo)
  if not ammo_inventory or not ammo_inventory.is_empty() then
    return
  end
  local ammo_types = {"explosive-rocket", "rocket"}
  for _, ammo_name in ipairs(ammo_types) do
    local available = cargo_inventory.get_item_count(ammo_name)
    if available > 0 then
      local inserted = ammo_inventory.insert{name = ammo_name, count = available}
      if inserted > 0 then
        cargo_inventory.remove{name = ammo_name, count = inserted}
        return
      end
    end
  end
end

local function ensure_entry(ship)
  if not (ship and ship.valid) then
    return
  end
  ensure_globals()
  if ship.name == BATTLESHIP_NAME or ship.name == INDEP_BATTLESHIP_NAME then
    local entry = storage.battleships[ship.unit_number]
    if not entry then
      entry = {ship = ship, turrets = {}, last_chart_tick = nil}
      storage.battleships[ship.unit_number] = entry
    else
      entry.ship = ship
    end
    sync_battleship_turrets(entry)
    chart_ship_area(entry)
  elseif ship.name == PATROL_BOAT_NAME or ship.name == INDEP_PATROL_BOAT_NAME then
    local entry = storage.patrol_boats[ship.unit_number]
    if not entry then
      entry = {ship = ship, turret = nil, last_chart_tick = nil}
      storage.patrol_boats[ship.unit_number] = entry
    else
      entry.ship = ship
    end
    sync_patrol_turret(entry)
    chart_ship_area(entry)
  else
    return
  end
end

local function remove_ship(ship)
  if not ship then
    return
  end
  ensure_globals()
  local entry = storage.battleships[ship.unit_number]
  if entry then
    destroy_turrets(entry)
    storage.battleships[ship.unit_number] = nil
  end
  local patrol_entry = storage.patrol_boats[ship.unit_number]
  if patrol_entry then
    if patrol_entry.turret and patrol_entry.turret.valid then
      patrol_entry.turret.destroy()
    end
    storage.patrol_boats[ship.unit_number] = nil
  end
end

local function on_nth_tick()
  if not storage.battleships and not storage.patrol_boats then
    return
  end
  if storage.battleships then
    for unit_number, entry in pairs(storage.battleships) do
      if not (entry.ship and entry.ship.valid) then
        destroy_turrets(entry)
        storage.battleships[unit_number] = nil
      else
        sync_battleship_turrets(entry)
        refill_battleship_ammo(entry)
        chart_ship_area(entry)
      end
    end
  end
  if storage.patrol_boats then
    for unit_number, entry in pairs(storage.patrol_boats) do
      if not (entry.ship and entry.ship.valid) then
        if entry.turret and entry.turret.valid then
          entry.turret.destroy()
        end
        storage.patrol_boats[unit_number] = nil
      else
        sync_patrol_turret(entry)
        refill_patrol_ammo(entry)
        chart_ship_area(entry)
      end
    end
  end
end

local function on_built(event)
  local entity = event.entity or event.destination
  if entity and entity.valid and (entity.name == BATTLESHIP_NAME or entity.name == INDEP_BATTLESHIP_NAME or entity.name == PATROL_BOAT_NAME or entity.name == INDEP_PATROL_BOAT_NAME) then
    ensure_entry(entity)
  end
end

local function on_removed(event)
  local entity = event.entity
  if entity and entity.valid and (entity.name == BATTLESHIP_NAME or entity.name == INDEP_BATTLESHIP_NAME or entity.name == PATROL_BOAT_NAME or entity.name == INDEP_PATROL_BOAT_NAME) then
    remove_ship(entity)
  end
end

local function init_existing()
  ensure_globals()
  for _, surface in pairs(game.surfaces) do
    local ships = surface.find_entities_filtered{name = {BATTLESHIP_NAME, INDEP_BATTLESHIP_NAME, PATROL_BOAT_NAME, INDEP_PATROL_BOAT_NAME}}
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
  register_ships()
  init_existing()
  init_events()
end)

script.on_configuration_changed(function()
  ensure_globals()
  register_ships()
  init_existing()
  init_events()
end)

script.on_load(function()
  init_events()
end)
