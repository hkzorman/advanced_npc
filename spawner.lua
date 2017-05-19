-- Advanced NPC spawner by Zorman2000
-- The advanced spawner will contain functionality to spawn NPC correctly on
-- mg_villages building. The spawn node will be the mg_villages:plotmarker.
-- This node will be replaced with one that will perform the following functions:
-- 
--  - Scan the current building, check if it is of type:
--    - House
--    - Farm
--    - Hut
--    - NOTE: All other types are unsupported as-of now
--  - If it's from any of the above types, the spawner will proceed to scan the
--    the building and find out: 
--    - Number and positions of beds
--    - Number and positions of benches
--    - Number and positions of chests
--    - Position of furnaces
--    - Position of doors
--    - NOTE: Scanning will be implemented for first floors only in the first
--            version. It's expected to also include upper floors later.
--  - After that, it will store these information in the node's metadata.
--  - The spawner will analyze the information and will spawn (# of beds/2) or 1
--    NPC in that house. The NPCs will be spawned in intervals, for which the node
--    will create node timers for each NPC.
--  - When a NPC is spawned:
--    - The NPC will be given a schedule
--      - If in a farm, the NPC will have a "farmer schedule" with a 40% chance
--      - If in a house or hut, the NPC will have either a miner, woodcutter, cooker
--        or simple schedule with an equal chance each
--    - The NPC will be assigned a unique bed
--    - The NPC will know the location of one chest, one bench and one furnace
--    - A life timer for the NPC will be created (albeit a long one). Once the NPC's
--      timer is invoked, the NPC will be de-spawned (dies). The spawner should keep
--      track of these.
--  - If a NPC has died, the spawner will choose with 50% chance to spawn a new NPC.
--
-- This is the basic functionality expected for the spawner in version 1. Other things
-- such as scanning upper floors, spawning families of NPCs and creating relationships
-- among them, etc. will be for other versions.

-- Public API
npc.spawner = {}
-- Private API
local spawner = {}

-- This is the official list of support building types
-- from the mg_villages mod
npc.spawner.mg_villages_supported_building_types = {
    "house",
    "farm_full",
    "farm_tiny",
    "hut",
    "lumberjack"
}

npc.spawner.replace_activated = true
npc.spawner.replacement_interval = 60
npc.spawner.spawn_delay = 10

npc.spawner.spawn_data = {
 status = {
    ["dead"] = 0,
    ["alive"] = 1
  }
}

---------------------------------------------------------------------------------------
-- Scanning functions
---------------------------------------------------------------------------------------

function spawner.filter_first_floor_nodes(nodes, ground_pos)
  local result = {}
  for _,node in pairs(nodes) do
    if node.node_pos.y <= ground_pos.y + 3 then
      table.insert(result, node)
    end
  end
  return result
end

-- Creates an array of {pos=<node_pos>, owner=''} for managing
-- which NPC owns what
function spawner.get_nodes_by_type(start_pos, end_pos, type)
  local result = {}
  local nodes = npc.places.find_node_in_area(start_pos, end_pos, type)
  --minetest.log("Found "..dump(#nodes).." nodes of type: "..dump(type))
  for _,node_pos in pairs(nodes) do
    local entry = {}
    entry["node_pos"] = node_pos
    entry["owner"] = ''
    table.insert(result, entry)
  end
  return result
end

-- Scans an area for the supported nodes: beds, benches,
-- furnaces, storage (e.g. chests) and openable (e.g. doors).
-- Returns a table with these classifications
function spawner.scan_area(pos1, pos2)

  local result = {
    bed_type = {},
    sittable_type = {},
    furnace_type = {},
    storage_type = {},
    openable_type = {}
  }
  local start_pos, end_pos = vector.sort(pos1, pos2)
 
  result.bed_type = spawner.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.BED_TYPE)
  result.sittable_type = spawner.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.SITTABLE_TYPE)
  result.furnace_type = spawner.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.FURNACE_TYPE)
  result.storage_type = spawner.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.STORAGE_TYPE)
  result.openable_type = spawner.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.OPENABLE_TYPE)

  --minetest.log("Found nodes inside area: "..dump(result))
  return result
end

-- This function will assign places to every NPC that belongs to a specific
-- house/building. It will use the resources of the house and give them
-- until there's no more. Call this function after NPCs are initialized
-- The basic assumption:
--   - Use only items that are up to y+3 (first floor of building) for now
--   - Tell the NPC where the furnaces are
--   - Assign a unique bed to the NPC
--   - If there are as many chests as beds, assign one to a NPC
--     - Else, just let the NPC know one of the chests, but not to be owned
--   - If there are as many benches as beds, assign one to a NPC
--     - Else, just let the NPC know one of the benches, but not own them
--   - Let the NPC know all doors to the house. Identify the front one as the entrance
function spawner.assign_places(self, pos)
  local meta = minetest.get_meta(pos)
  local doors = minetest.deserialize(meta:get_string("node_data")).openable_type
  minetest.log("Found "..dump(#doors).." openable nodes")

  local entrance = npc.places.find_entrance_from_openable_nodes(doors, pos)
  if entrance then
    minetest.log("Found building entrance at: "..minetest.pos_to_string(entrance.node_pos))
  else
    minetest.log("Unable to find building entrance!")
  end

  -- Assign entrance door and related locations
  if entrance ~= nil and entrance.node_pos ~= nil then
    -- For debug purposes:
    --local meta = minetest.get_meta(entrance.node_pos)
    --meta:set_string("infotext", "Entrance for '"..dump(self.nametag).."': "..dump(entrance.node_pos))
    --minetest.log("Self: "..dump(self))
    --minetest.log("Places map: "..dump(self.places_map))
    npc.places.add_public(self, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, entrance.node_pos)
    -- Find the position inside and outside the door
    local entrance_inside = npc.places.find_node_behind_door(entrance.node_pos)
    local entrance_outside = npc.places.find_node_in_front_of_door(entrance.node_pos)
    --minetest.set_node(entrance_inside, {name="default:apple"})
    -- Assign these places to NPC
    npc.places.add_public(self, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, entrance_inside)
    npc.places.add_public(self, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, entrance_outside)
    -- Make NPC go into their house
    --minetest.log("Place: "..dump(npc.places.get_by_type(self, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE)))
    npc.add_task(self, npc.actions.cmd.WALK_TO_POS, {end_pos=npc.places.get_by_type(self, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE)[1].pos, walkable={}})  
    npc.add_action(self, npc.actions.cmd.FREEZE, {freeze = false})
  end

  local plot_info = minetest.deserialize(meta:get_string("plot_info"))
  minetest.log("Plot info:"..dump(plot_info))


end

-- This function is called when the node timer for spawning NPC
-- is expired 
function npc.spawner.spawn_npc(pos)
  -- Get timer
  local timer = minetest.get_node_timer(pos)
  -- Get metadata
  local meta = minetest.get_meta(pos)
  -- Check amount of NPCs that should be spawned
  local npc_count = meta:get_int("npc_count")
  local spawned_npc_count = meta:get_int("spawned_npc_count")
  minetest.log("Currently spawned "..dump(spawned_npc_count).." of "..dump(npc_count).." NPCs")
  if spawned_npc_count < npc_count then
    minetest.log("[advanced_npc] Spawning NPC at "..minetest.pos_to_string(pos))
    -- Spawn a NPC
    local ent = minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, "advanced_npc:npc")
    if ent and ent:get_luaentity() then
      ent:get_luaentity().initialized = false
      npc.initialize(ent, pos)
      -- Assign nodes
      spawner.assign_places(ent:get_luaentity(), pos)
      -- Increase NPC spawned count
      spawned_npc_count = spawned_npc_count + 1
      -- Store count into node
      meta:set_int("spawned_npc_count", spawned_npc_count)
      -- Store spawned NPC data into node
      local npc_table = minetest.deserialize(meta:get_string("npcs"))
      -- TODO: Add more information here at some time...
      local entry = {
        status = npc.spawner.spawn_data.status.alive,
        name = ent:get_luaentity().nametag,
        id = ent:get_luaentity().npc_id,
        born_day = minetest.get_day_count()
      }
      table.insert(npc_table, entry)
      -- Store into metadata
      meta:set_string("npcs", minetest.serialize(npc_table))
      -- Temp
      meta:set_string("infotext", meta:get_string("infotext")..", "..spawned_npc_count)
      minetest.log("[advanced_npc] Spawning successful!")
      -- Check if there are more NPCs to spawn
      if spawned_npc_count >= npc_count then
        -- Stop timer
        minetest.log("[advanced_npc] No more NPCs to spawn at this location")
        timer:stop()
      else
        -- Start another timer to spawn more NPC
        minetest.log("[advanced_npc] Spawning one more NPC in "..dump(npc.spawner.spawn_delay).."s")
        timer:start(npc.spawner.spawn_delay)
      end
      return true
    else
        minetest.log("[advanced_npc] Spawning failed!")
        ent:remove()
      return false
    end
  end
  
end

-- This function takes care of calculating how many NPCs will be spawn
function spawner.calculate_npc_spawning(pos)
  -- Check node
  local node = minetest.get_node(pos)
  if node.name ~= "advanced_npc:plotmarker_auto_spawner" then
    return
  end 
  -- Check node metadata
  local meta = minetest.get_meta(pos)
  -- Get nodes for this building
  local node_data = minetest.deserialize(meta:get_string("node_data"))
  if node_data == nil then
    minetest.log("[advanced_npc] ERROR: Mis-configured advanced_npc:plotmarker_auto_spawner at position: "..minetest.pos_to_string(pos))
    return
  end
  -- Check number of beds
  local beds_count = #node_data.bed_type
  minetest.log("[advanced_npc] INFO: Found "..dump(beds_count).." beds in the building at "..minetest.pos_to_string(pos))
  local npc_count = 0
  -- If number of beds is zero or beds/2 is less than one, spawn
  -- a single NPC.
  if beds_count == 0 or (beds_count > 0 and beds_count / 2 < 1) then
    -- Spawn a single NPC
    npc_count = 1
  else
    -- Spawn beds_count/2 NPCs
    npc_count = ((beds_count / 2) - ((beds_count / 2) % 1))
  end
  minetest.log("Will spawn "..dump(npc_count).." NPCs at "..minetest.pos_to_string(pos))
  -- Store amount of NPCs to spawn
  meta:set_int("npc_count", npc_count)
  -- Store amount of NPCs spawned
  meta:set_int("spawned_npc_count", 0)
  -- Start timer
  local timer = minetest.get_node_timer(pos)
  timer:start(npc.spawner.spawn_delay)
end

---------------------------------------------------------------------------------------
-- Support code for mg_villages mods
---------------------------------------------------------------------------------------

-- This function creates a table of the scannable nodes inside
-- a mg_villages building. It needs the plotmarker position for a start
-- point and the building_data to get the x, y and z-coordinate size
-- of the building schematic
function spawner.scan_mg_villages_building(pos, building_data)
  minetest.log("--------------------------------------------")
  minetest.log("Building data: "..dump(building_data))
  minetest.log("--------------------------------------------")
  -- Get area of the building
  local x_size = building_data.bsizex
  local y_size = building_data.ysize
  local z_size = building_data.bsizez
  local brotate = building_data.brotate
  local start_pos = {x=pos.x, y=pos.y, z=pos.z}
  local x_sign, z_sign = 1, 1

  -- Check plot direction
  -- 0 - facing West, -X
  -- 1 - facing North, +Z
  -- 2 - facing East, +X
  -- 3 - facing South -Z
  if brotate == 0 then
    x_sign, z_sign = 1, -1
  elseif brotate == 1 then
    x_sign, z_sign =  -1, -1
    local temp = z_size
    z_size = x_size
    x_size = temp
  elseif brotate == 2 then
    x_sign, z_sign = -1, 1
  elseif brotate == 3 then
    x_sign, z_sign = 1, 1
  end

  ------------------------
  -- For debug:
  ------------------------
  -- Red is x marker
  --minetest.set_node({x=pos.x + (x_sign * x_size),y=pos.y,z=pos.z}, {name = "wool:red"})
  --minetest.get_meta({x=pos.x + (x_sign * x_size),y=pos.y,z=pos.z}):set_string("infotext", minetest.get_meta(pos):get_string("infotext")..", Axis: x, Sign: "..dump(x_sign))
  -- Blue is z marker
  --minetest.set_node({x=pos.x,y=pos.y,z=pos.z + (z_sign * z_size)}, {name = "wool:blue"})
  --minetest.get_meta({x=pos.x,y=pos.y,z=pos.z + (z_sign * z_size)}):set_string("infotext", minetest.get_meta(pos):get_string("infotext")..", Axis: z, Sign: "..dump(z_sign))
  
  minetest.log("Start pos: "..minetest.pos_to_string(start_pos))
  minetest.log("Plot: "..dump(minetest.get_meta(start_pos):get_string("infotext")))

  minetest.log("Brotate: "..dump(brotate))
  minetest.log("X_sign: "..dump(x_sign))
  minetest.log("X_adj: "..dump(x_sign*x_size))
  minetest.log("Z_sign: "..dump(z_sign))
  minetest.log("Z_adj: "..dump(z_sign*z_size))

  local end_pos = {x=pos.x + (x_sign * x_size), y=pos.y + y_size, z=pos.z + (z_sign * z_size)}

  -- For debug:
  --minetest.set_node(start_pos, {name="default:mese_block"})
  --minetest.set_node(end_pos, {name="default:mese_block"})
  --minetest.get_meta(end_pos):set_string("infotext", minetest.get_meta(start_pos):get_string("infotext"))

  minetest.log("Calculated end pos: "..minetest.pos_to_string(end_pos))

  return spawner.scan_area(start_pos, end_pos)
end

-- This function replaces an existent mg_villages:plotmarker with
-- and advanced_npc:auto_spawner. The existing metadata will be kept,
-- to allow compatibility. A new formspec will appear on right-click,
-- however it will as well allow to buy or manage the plot.
-- Also, the building is scanned for NPC-usable nodes and the amount
-- of NPCs to spawn and the interval is calculated.
function spawner.replace_mg_villages_plotmarker(pos)
  -- Get the meta at the current position
  local meta = minetest.get_meta(pos)
  local village_id = meta:get_string("village_id")
  local plot_nr = meta:get_int("plot_nr")
  local infotext = meta:get_string("infotext")
  -- Following line from mg_villages mod, protection.lua
  local btype = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr].btype
  local building_data = mg_villages.BUILDINGS[btype]
  local building_type = building_data.typ 
  -- Check if the building is of the support types
  for _,value in pairs(npc.spawner.mg_villages_supported_building_types) do

    if building_type == value then

      minetest.log("Replacing mg_villages:plotmarker at "..minetest.pos_to_string(pos))
      -- Replace the plotmarker for auto-spawner
      minetest.set_node(pos, {name="advanced_npc:plotmarker_auto_spawner"})
      -- Store old plotmarker metadata again
      meta:set_string("village_id", village_id)
      meta:set_int("plot_nr", plot_nr)
      meta:set_string("infotext", infotext)
      -- Store building type in metadata
      meta:set_string("building_type", building_type)
      -- Store plot information
      local plot_info = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr]
      plot_info["ysize"] = building_data.ysize
      -- minetest.log("Plot info at replacement time: "..dump(plot_info))
      meta:set_string("plot_info", minetest.serialize(plot_info))
      -- Scan building for nodes
      local nodedata = spawner.scan_mg_villages_building(pos, plot_info)
      -- Store nodedata into the spawner's metadata
      meta:set_string("node_data", minetest.serialize(nodedata))
      -- Initialize NPCs
      local npcs = {}
      meta:set_string("npcs", minetest.serialize(npcs))
      -- Stop searching for building type
      break

    end
  end
end

-- Only register the node, the ABM and the LBM if mg_villages mod
-- is present
if minetest.get_modpath("mg_villages") ~= nil then

  -- Node registration
  -- This node is currently a slightly modified mg_villages:plotmarker
  -- TODO: Change formspec to a more detailed one.
  minetest.register_node("advanced_npc:plotmarker_auto_spawner", {
    description = "Automatic NPC Spawner",
    drawtype = "nodebox",
    tiles = {"default_stone.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5+2/16, -0.5, -0.5+2/16,  0.5-2/16, -0.5+2/16, 0.5-2/16},
        }
    },
    groups = {cracky=3,stone=2},

    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
      -- Get all openable-type nodes for this building
      -- NOTE: This is temporary code for testing...

      return mg_villages.plotmarker_formspec( pos, nil, {}, clicker )
    end,

    on_receive_fields = function(pos, formname, fields, sender)
      return mg_villages.plotmarker_formspec( pos, formname, fields, sender );
    end,

    on_timer = function(pos, elapsed)
      npc.spawner.spawn_npc(pos)
    end,

    -- protect against digging
    can_dig = function(pos, player)
      local meta = minetest.get_meta(pos);
      if (meta and meta:get_string("village_id") ~= "" and meta:get_int("plot_nr") and meta:get_int("plot_nr") > 0 ) then
          return false;
      end
      return true;
    end
  })

  -- LBM Registration
  -- Used to modify plotmarkers and replace them with advanced_npc:plotmarker_auto_spawner
  -- minetest.register_lbm({
  --   label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
  --   name = "advanced_npc:mg_villages_plotmarker_replacer",
  --   nodenames = {"mg_villages:plotmarker"},
  --   run_at_every_load = false,
  --   action = function(pos, node)
  --     -- Check if replacement is activated
  --     if npc.spawner.replace_activated then
  --       -- Replace mg_villages:plotmarker
  --       spawner.replace_mg_villages_plotmarker(pos)
  --       -- Set NPCs to spawn
  --       spawner.calculate_npc_spawning(pos)
  --     end
  --   end
  -- })

  -- ABM Registration... for when LBM fails.
  minetest.register_abm({
    label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    nodenames = {"mg_villages:plotmarker"},
    interval = npc.spawner.replacement_interval,
    chance = 5,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
       -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
        -- Set NPCs to spawn
        spawner.calculate_npc_spawning(pos)
      end
    end
  })

end

-- Chat commands to manage spawners
minetest.register_chatcommand("restore_plotmarkers", {
  description = "Replaces all advanced_npc:plotmarker_auto_spawner with mg_villages:plotmarker in the specified radius.",
  privs = {server=true},
  func = function(name, param)
    -- Check if radius is null
    if param == nil then
      minetest.chat_send_player(name, "Need to enter a radius as an integer number. Ex. /restore_plotmarkers 10 for a radius of 10")
    end
    -- Get player position
    local pos = {}
    for _,player in pairs(minetest.get_connected_players()) do
      if player:get_player_name() == name then
        pos = player:get_pos()
        break
      end
    end
    -- Search for nodes
    local radius = tonumber(param)
    local start_pos = {x=pos.x - radius, y=pos.y - radius, z=pos.z - radius}
    local end_pos = {x=pos.x + radius, y=pos.y + radius, z=pos.z + radius}
    local nodes = minetest.find_nodes_in_area_under_air(start_pos, end_pos, 
      {"advanced_npc:plotmarker_auto_spawner"})
    -- Check if we have nodes to replace
    minetest.chat_send_player(name, "Found "..dump(#nodes).." nodes to replace...")
    if #nodes == 0 then
      return
    end
    -- Replace all nodes
    for i = 1, #nodes do
      --minetest.log(dump(nodes[i]))
      local meta = minetest.get_meta(nodes[i])
      local village_id = meta:get_string("village_id")
      local plot_nr = meta:get_int("plot_nr")
      local infotext = meta:get_string("infotext")
      -- Replace node
      minetest.set_node(nodes[i], {name="mg_villages:plotmarker"})
      -- Set metadata
      meta = minetest.get_meta(nodes[i])
      meta:set_string("village_id", village_id)
      meta:set_int("plot_nr", plot_nr)
      meta:set_string("infotext", infotext)
    end
    minetest.chat_send_player(name, "Finished replacement of "..dump(#nodes).." auto-spawners successfully")
  end
})