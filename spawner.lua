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
    	dead = 0,
    	alive = 1
  	},
  	age = {
  		adult = "adult",
  		child = "child"
	}
}

local function get_basic_schedule()
	return {
		-- Create schedule entries
		-- Morning actions: get out of bed, walk to outside of house
		-- This will be executed around 8 AM MTG time
		morning_actions = {
			-- Get out of bed
			[1] = {task = npc.actions.cmd.USE_BED, args = {
					pos = npc.places.PLACE_TYPE.BED.PRIMARY, 
					action = npc.actions.const.beds.GET_UP
				} 
			}, 
			-- Walk outside
			[2] = {task = npc.actions.cmd.WALK_TO_POS, args = {
					end_pos = npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, 
					walkable = {}
				} 
			},
			-- Allow mobs_redo wandering
			[3] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
		},
		-- Noon actions: go inside the house
		-- This will be executed around 12 PM MTG time
		noon_actions = {
			-- Walk to a sittable node
			[1] = {task = npc.actions.cmd.WALK_TO_POS, args = {
					end_pos = {place_type=npc.places.PLACE_TYPE.SITTABLE.PRIMARY, use_access_node=true},
					walkable = {"cottages:bench"}
				} 
			},
			-- Sit on the node
			[2] = {task = npc.actions.cmd.USE_SITTABLE, args = {
					pos = npc.places.PLACE_TYPE.SITTABLE.PRIMARY,
					action = npc.actions.const.sittable.SIT
				}
			},
			-- Stay put into place
			[3] = {action = npc.actions.cmd.FREEZE, args = {freeze = true}}
		},
		-- Afternoon actions: go inside the house
		-- This will be executed around 1 PM MTG time
		afternoon_actions = {
			--  Get up of the sit
			[1] = {task = npc.actions.cmd.USE_SITTABLE, args = {
					pos = npc.places.PLACE_TYPE.SITTABLE.PRIMARY, 
					action = npc.actions.const.sittable.GET_UP
				} 
			},
			-- Give NPC money to buy from player
			[2] = {property = npc.schedule_properties.put_multiple_items, args = {
					itemlist = {
						{name="default:iron_lump", random=true, min=2, max=4}
					}
				}
			},
			-- Change trader status to "trader"
			[3] = {property = npc.schedule_properties.trader_status, args = {
					status = npc.trade.TRADER
				}
			},
			[4] = {property = npc.schedule_properties.can_receive_gifts, args = {
					value = true
				}
			},
			-- Allow mobs_redo wandering
			[5] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
		},
		-- Afternoon actions: go inside the house
		-- This will be executed around 6 PM MTG time
		late_afternoon_actions = { 
			-- Change trader status to "none"
			[1] = {property = npc.schedule_properties.trader_status, args = {
					status = npc.trade.NONE
				}
			},
			-- Enable gift receiving again
			[2] = {property = npc.schedule_properties.can_receive_gifts, args = {
					can_receive_gifts = true
				}
			},
			-- Get inside home
			[3] = {task = npc.actions.cmd.WALK_TO_POS, args = {
					end_pos = npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, 
					walkable = {}} 
				},
			-- Allow mobs_redo wandering
			[4] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
		},
		-- Evening actions: walk to bed and use it.
		-- This will be executed around 10 PM MTG time
		evening_actions = { 
			[1] = {task = npc.actions.cmd.WALK_TO_POS, args = {
					end_pos = {place_type=npc.places.PLACE_TYPE.BED.PRIMARY, use_access_node=true}, 
					walkable = {}
				} 
			},
			-- Use bed
			[2] = {task = npc.actions.cmd.USE_BED, args = {
					pos = npc.places.PLACE_TYPE.BED.PRIMARY, 
					action = npc.actions.const.beds.LAY
				} 
			}, 
			-- Stay put on bed
			[3] = {action = npc.actions.cmd.FREEZE, args = {freeze = true}}
		}
	}
end

---------------------------------------------------------------------------------------
-- Scanning functions
---------------------------------------------------------------------------------------

function spawner.filter_first_floor_nodes(nodes, ground_pos)
  local result = {}
  for _,node in pairs(nodes) do
    if node.node_pos.y <= ground_pos.y + 2 then
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
  -- Filter out 
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
  local entrance = minetest.deserialize(meta:get_string("entrance"))
  local node_data = minetest.deserialize(meta:get_string("node_data"))

  -- Assign plotmarker
  npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_PLOTMARKER,
  	npc.places.PLACE_TYPE.OTHER.HOME_PLOTMARKER, pos)

  -- Assign entrance door and related locations
  if entrance ~= nil and entrance.node_pos ~= nil then
    npc.places.add_shared(self, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, entrance.node_pos)
    -- Find the position inside and outside the door
    local entrance_inside = npc.places.find_node_behind_door(entrance.node_pos)
    local entrance_outside = npc.places.find_node_in_front_of_door(entrance.node_pos)
    -- Assign these places to NPC
    npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, entrance_inside)
    npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, entrance_outside)
  end

  -- Assign beds
  if #node_data.bed_type > 0 then
  	-- Assign a specific sittable node to a NPC.
	npc.places.add_unowned_accessible_place(self, node_data.bed_type, 
		npc.places.PLACE_TYPE.BED.PRIMARY)
	-- Store changes to node_data
	meta:set_string("node_data", minetest.serialize(node_data)) 
  end

  -- Assign sits
  if #node_data.sittable_type > 0 then
  	-- Check if there are same or more amount of sits as beds
  	if #node_data.sittable_type >= #node_data.bed_type then
  		-- Assign a specific sittable node to a NPC.
  		npc.places.add_unowned_accessible_place(self, node_data.sittable_type, 
  			npc.places.PLACE_TYPE.SITTABLE.PRIMARY)
  		-- Store changes to node_data
  		meta:set_string("node_data", minetest.serialize(node_data)) 
  	end
  	-- Add all sits to places as shared since NPC should be able to sit
  	-- at any accessible sit
  	npc.places.add_shared_accessible_place(self, node_data.sittable_type, 
  		npc.places.PLACE_TYPE.SITTABLE.SHARED)
  end

  -- Assign furnaces
  if #node_data.furnace_type > 0 then
  	-- Check if there are same or more amount of furnace as beds
  	if #node_data.furnace_type >= #node_data.bed_type then
  		-- Assign a specific furnace node to a NPC.
  		npc.places.add_unowned_accessible_place(self, node_data.furnace_type, 
  			npc.places.PLACE_TYPE.FURNACE.PRIMARY)
  		-- Store changes to node_data
  		meta:set_string("node_data", minetest.serialize(node_data)) 
  	end
  	-- Add all furnaces to places as shared since NPC should be able to use
  	-- any accessible furnace
  	npc.places.add_shared_accessible_place(self, node_data.furnace_type, 
  		npc.places.PLACE_TYPE.FURNACE.SHARED)
  end

  -- Assign storage nodes
  if #node_data.storage_type > 0 then
  	-- Check if there are same or more amount of storage as beds
  	if #node_data.storage_type >= #node_data.bed_type then
  		-- Assign a specific storage node to a NPC.
  		npc.places.add_unowned_accessible_place(self, node_data.storage_type, 
  			npc.places.PLACE_TYPE.STORAGE.PRIMARY)
  		-- Store changes to node_data
  		meta:set_string("node_data", minetest.serialize(node_data)) 
  	end
  	-- Add all storage-types to places as shared since NPC should be able
  	-- to use other storage nodes as well.
  	npc.places.add_shared_accessible_place(self, node_data.storage_type, 
  		npc.places.PLACE_TYPE.STORAGE.SHARED)
  end

  npc.log("DEBUG", "Places for NPC "..self.npc_name..": "..dump(self.places_map))

  	-- Make NPC go into their house
	npc.add_task(self, 
		npc.actions.cmd.WALK_TO_POS, 
		{end_pos=npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
		 walkable={}})
	npc.add_action(self, npc.actions.cmd.FREEZE, {freeze = false})
end


function spawner.assign_schedules(self, pos)
	-- TODO: In the future, this needs to actually take into account
	-- type of building and different schedules, e.g. farmers, traders, etc.
	local basic_schedule = get_basic_schedule()
	-- Add a simple schedule for testing
  	npc.create_schedule(self, npc.schedule_types.generic, 0)
	-- Add schedule entry for morning actions
	npc.add_schedule_entry(self, npc.schedule_types.generic, 0, 8, nil, basic_schedule.morning_actions)

	-- Add schedule entry for noon actions
	npc.add_schedule_entry(self, npc.schedule_types.generic, 0, 12, nil, basic_schedule.noon_actions)
	
	-- Add schedule entry for afternoon actions
	npc.add_schedule_entry(self, npc.schedule_types.generic, 0, 13, nil, basic_schedule.afternoon_actions)

	-- Add schedule entry for late afternoon actions
	npc.add_schedule_entry(self, npc.schedule_types.generic, 0, 18, nil, basic_schedule.late_afternoon_actions)

	-- Add schedule entry for evening actions
	npc.add_schedule_entry(self, npc.schedule_types.generic, 0, 22, nil, basic_schedule.evening_actions)
end

-- This function is called when the node timer for spawning NPC
-- is expired 
function npc.spawner.spawn_npc(pos)
  -- Get timer
  local timer = minetest.get_node_timer(pos)
  -- Get metadata
  local meta = minetest.get_meta(pos)
  -- Get current NPC info
  local npc_table = minetest.deserialize(meta:get_string("npcs"))
  -- Get NPC stats
  local npc_stats = minetest.deserialize(meta:get_string("npc_stats"))
  -- Check amount of NPCs that should be spawned
  local npc_count = meta:get_int("npc_count")
  local spawned_npc_count = meta:get_int("spawned_npc_count")
  npc.log("INFO", "Currently spawned "..dump(spawned_npc_count).." of "..dump(npc_count).." NPCs")
  if spawned_npc_count < npc_count then
    npc.log("INFO", "Spawning NPC at "..minetest.pos_to_string(pos))
    -- Spawn a NPC
    local ent = minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, "advanced_npc:npc")
    if ent and ent:get_luaentity() then
      ent:get_luaentity().initialized = false
      -- Initialize NPC
      -- Call with stats if there are NPCs
      if #npc_table > 0 then
      	npc.initialize(ent, pos, false, npc_stats)
      else
      	npc.initialize(ent, pos)
      end
      -- Assign nodes
      spawner.assign_places(ent:get_luaentity(), pos)
      -- Assign schedules
      spawner.assign_schedules(ent:get_luaentity(), pos)
      -- Increase NPC spawned count
      spawned_npc_count = spawned_npc_count + 1
      -- Store count into node
      meta:set_int("spawned_npc_count", spawned_npc_count)
      -- Store spawned NPC data and stats into node
      local age = npc.age.adult
      if ent:get_luaentity().child then
      	age = npc.age.child
      end 
      -- TODO: Add more information here at some time...
      local entry = {
        status = npc.spawner.spawn_data.status.alive,
        name = ent:get_luaentity().name,
        id = ent:get_luaentity().npc_id,
        sex = ent:get_luaentity().sex,
        age = age,
        born_day = minetest.get_day_count()
      }
      table.insert(npc_table, entry)
      meta:set_string("npcs", minetest.serialize(npc_table))
      -- Update and store stats
      -- Increase total of NPCs for specific sex
      npc_stats[ent:get_luaentity().sex].total = 
      	npc_stats[ent:get_luaentity().sex].total + 1
      -- Increase total number of NPCs by age
      npc_stats[age.."_total"] = npc_stats[age.."_total"] + 1
      -- Increase number of NPCs by age and sex
      npc_stats[ent:get_luaentity().sex][age] = 
      	npc_stats[ent:get_luaentity().sex][age] + 1
      meta:set_string("npc_stats", minetest.serialize(npc_stats))
      -- Temp
      --meta:set_string("infotext", meta:get_string("infotext")..", "..spawned_npc_count)
      npc.log("INFO", "Spawning successful!")
      -- Check if there are more NPCs to spawn
      if spawned_npc_count >= npc_count then
        -- Stop timer
        npc.log("INFO", "No more NPCs to spawn at this location")
        timer:stop()
      else
        -- Start another timer to spawn more NPC
        local new_delay = math.random(npc.spawner.spawn_delay)
        npc.log("INFO", "Spawning one more NPC in "..dump(npc.spawner.spawn_delay).."s")
        timer:start(new_delay)
      end
      return true
    else
        npc.log("ERROR", "Spawning failed!")
        ent:remove()
      return false
    end
  end
  
end

-- This function takes care of calculating how many NPCs will be spawn
function spawner.calculate_npc_spawning(pos)
  -- Check node metadata
  local meta = minetest.get_meta(pos)
  if meta:get_string("replaced") ~= "true" then
  	return
  end
  -- Get nodes for this building
  local node_data = minetest.deserialize(meta:get_string("node_data"))
  if node_data == nil then
    npc.log("ERROR", "Mis-configured mg_villages:plotmarker at position: "..minetest.pos_to_string(pos))
    return
  end
  -- Check number of beds
  local beds_count = #node_data.bed_type--#spawner.filter_first_floor_nodes(node_data.bed_type, pos)
  
  npc.log("DEBUG", "Found "..dump(beds_count).." beds in the building at "..minetest.pos_to_string(pos))
  local npc_count = 0
  -- If number of beds is zero or beds/2 is less than one, spawn
  -- a single NPC.
  if beds_count == 0 or (beds_count > 0 and beds_count / 2 < 1) then
    -- Spawn a single NPC
    npc_count = 1
  else
    -- Spawn (beds_count/2) NPCs
    npc_count = ((beds_count / 2) - ((beds_count / 2) % 1))
  end
  npc.log("INFO", "Will spawn "..dump(npc_count).." NPCs at "..minetest.pos_to_string(pos))
  -- Store amount of NPCs to spawn
  meta:set_int("npc_count", npc_count)
  -- Store amount of NPCs spawned
  meta:set_int("spawned_npc_count", 0)
  -- Start timer
  local timer = minetest.get_node_timer(pos)
  local delay = math.random(npc.spawner.spawn_delay)
  timer:start(delay)
end

---------------------------------------------------------------------------------------
-- Support code for mg_villages mods
---------------------------------------------------------------------------------------

-- This function creates a table of the scannable nodes inside
-- a mg_villages building. It needs the plotmarker position for a start
-- point and the building_data to get the x, y and z-coordinate size
-- of the building schematic
function spawner.scan_mg_villages_building(pos, building_data)
  --minetest.log("--------------------------------------------")
  --minetest.log("Building data: "..dump(building_data))
  --minetest.log("--------------------------------------------")
  -- Get area of the building
  local x_size = building_data.bsizex
  local y_size = building_data.ysize
  local z_size = building_data.bsizez
  local brotate = building_data.brotate
  local start_pos = {x=pos.x, y=pos.y, z=pos.z}
  local x_sign, z_sign = 1, 1

  -- Check plot direction
  -- NOTE: Below values may be wrong, very wrong!
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
  
  npc.log("DEBUG", "Start pos: "..minetest.pos_to_string(start_pos))
  npc.log("DEBUG", "Plot: "..dump(minetest.get_meta(start_pos):get_string("infotext")))

  npc.log("DEBUG", "Brotate: "..dump(brotate))
  npc.log("DEBUG", "X_sign: "..dump(x_sign))
  npc.log("DEBUG", "X_adj: "..dump(x_sign*x_size))
  npc.log("DEBUG", "Z_sign: "..dump(z_sign))
  npc.log("DEBUG", "Z_adj: "..dump(z_sign*z_size))

  local end_pos = {x=pos.x + (x_sign * x_size), y=pos.y + y_size, z=pos.z + (z_sign * z_size)}

  -- For debug:
  --minetest.set_node(start_pos, {name="default:mese_block"})
  --minetest.set_node(end_pos, {name="default:mese_block"})
  --minetest.get_meta(end_pos):set_string("infotext", minetest.get_meta(start_pos):get_string("infotext"))

  npc.log("DEBUG", "Calculated end pos: "..minetest.pos_to_string(end_pos))

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
  -- Check for nil values above
  if (not village_id or (village and village == "")) 
  	or (not plot_nr or (plot_nr and plot_nr == 0)) then
  	return
  end
  -- Following line from mg_villages mod, protection.lua
  local btype = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr].btype
  local building_data = mg_villages.BUILDINGS[btype]
  local building_type = building_data.typ
  -- Check if the building is of the support types
  for _,value in pairs(npc.spawner.mg_villages_supported_building_types) do

    if building_type == value then

      npc.log("INFO", "Replacing mg_villages:plotmarker at "..minetest.pos_to_string(pos))
      -- Replace the plotmarker for auto-spawner
      --minetest.set_node(pos, {name="advanced_npc:plotmarker_auto_spawner"})
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
      -- Find building entrance
      local doors = nodedata.openable_type
      --minetest.log("Found "..dump(#doors).." openable nodes")
      local entrance = npc.places.find_entrance_from_openable_nodes(doors, pos)
      if entrance then
        npc.log("INFO", "Found building entrance at: "..minetest.pos_to_string(entrance.node_pos))
      else
        npc.log("ERROR", "Unable to find building entrance!")
      end
      -- Store building entrance
      meta:set_string("entrance", minetest.serialize(entrance))
      -- Store nodedata into the spawner's metadata
      meta:set_string("node_data", minetest.serialize(nodedata))
      -- Initialize NPCs
      local npcs = {}
      meta:set_string("npcs", minetest.serialize(npcs))
      -- Initialize NPC stats
      local npc_stats = {
      	male = {
      		total = 0,
      		adult = 0,
      		child = 0
      	},
      	female = {
      		total = 0,
      		adult = 0,
      		child = 0
      	},
      	adult_total = 0,
      	child_total = 0
  	  }
  	  meta:set_string("npc_stats", minetest.serialize(npc_stats))
  	  -- Set replaced
  	  meta:set_string("replaced", "true")
  	  -- Calculate how many NPCs will spawn
  	  spawner.calculate_npc_spawning(pos)
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
  minetest.override_item("mg_villages:plotmarker", {
    -- description = "Automatic NPC Spawner",
    -- drawtype = "nodebox",
    -- tiles = {"default_stone.png"},
    -- paramtype = "light",
    -- paramtype2 = "facedir",
    -- node_box = {
    --     type = "fixed",
    --     fixed = {
    --         {-0.5+2/16, -0.5, -0.5+2/16,  0.5-2/16, -0.5+2/16, 0.5-2/16},
    --         --{-0.5+0/16, -0.5, -0.5+0/16,  0.5-0/16, -0.5+0/16, 0.5-0/16},
    --     }
    -- },
    walkable = false,
    groups = {cracky=3,stone=2},

    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
      -- NOTE: This is temporary code for testing...
      local nodedata = minetest.deserialize(minetest.get_meta(pos):get_string("node_data"))
      --minetest.log("Node data: "..dump(nodedata))
      --minetest.log("Entrance: "..dump(minetest.deserialize(minetest.get_meta(pos):get_string("entrance"))))
      --minetest.log("First-floor beds: "..dump(spawner.filter_first_floor_nodes(nodedata.bed_type, pos)))
      --local entrance = npc.places.find_entrance_from_openable_nodes(nodedata.openable_type, pos)
      --minetest.log("Found entrance: "..dump(entrance))
      minetest.log("Replaced: "..dump(minetest.get_meta(pos):get_string("replaced")))
      -- for i = 1, #nodedata.bed_type do
      -- 	nodedata.bed_type[i].owner = ""
      -- end
      -- minetest.get_meta(pos):set_string("node_data", minetest.serialize(nodedata))
      -- minetest.log("Cleared bed owners")
      --minetest.log("NPC stats: "..dump(minetest.deserialize(minetest.get_meta(pos):get_string("npc_stats"))))

      return mg_villages.plotmarker_formspec( pos, nil, {}, clicker )
    end,

    -- on_receive_fields = function(pos, formname, fields, sender)
    --   return mg_villages.plotmarker_formspec( pos, formname, fields, sender );
    -- end,

    on_timer = function(pos, elapsed)
      npc.spawner.spawn_npc(pos)
    end,

    -- protect against digging
    -- can_dig = function(pos, player)
    --   local meta = minetest.get_meta(pos);
    --   if (meta and meta:get_string("village_id") ~= "" and meta:get_int("plot_nr") and meta:get_int("plot_nr") > 0 ) then
    --       return false;
    --   end
    --   return true;
    -- end
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

  -- ABM Registration
  minetest.register_abm({
    label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    nodenames = {"mg_villages:plotmarker"},
    interval = 10,--npc.spawner.replacement_interval,
    chance = 1,--5,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
      -- Check if replacement is needed
      if minetest.get_meta(pos):get_string("replaced") == "true" then
      	return
      end
       -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
      end
    end
  })

end

--minetest.register_alias_force("mg_villages:plotmarker", )

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
      {"mg_villages:plotmarker"})
    -- Check if we have nodes to replace
    minetest.chat_send_player(name, "Found "..dump(#nodes).." nodes to replace...")
    if #nodes == 0 then
      return
    end
    -- Replace all nodes
    for i = 1, #nodes do
      local meta = minetest.get_meta(nodes[i])
      local village_id = meta:get_string("village_id")
      local plot_nr = meta:get_int("plot_nr")
      local infotext = meta:get_string("infotext")
      -- Set metadata
      meta = minetest.get_meta(nodes[i])
      meta:set_string("village_id", village_id)
      meta:set_int("plot_nr", plot_nr)
      meta:set_string("infotext", infotext)
      -- Clear NPC stats, NPC data and node data
      meta:set_string("node_data", nil)
      meta:set_string("npcs", nil)
      meta:set_string("npc_stats", nil)
      meta:set_string("replaced", "false")
    end
    minetest.chat_send_player(name, "Finished replacement of "..dump(#nodes).." auto-spawners successfully")
  end
})