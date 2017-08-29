-- Places code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Places functionality
---------------------------------------------------------------------------------------
-- In addition, the NPCs need to know where some places are, and know
-- where there are nodes they can use. For example, they need to know where the
-- chest they use is located, both to walk to it and to use it. They also need
-- to know where the farm they work is located, or where the bed they sleep is.
-- Other mods have to be supported for this to work correctly, as there are
-- many sitting nodes, many beds, many tables, chests, etc. For now, by default,
-- support for default MTG games and cottages mod is going to be provided.

npc.places = {}

npc.places.nodes = {
	BED_TYPE = {
		"beds:bed_bottom",
		"beds:fancy_bed_bottom",
		"cottages:bed_foot",
		"cottages:straw_mat",
		"cottages:sleeping_mat"
	},
	SITTABLE_TYPE = {
		"cottages:bench",
		-- Currently commented out since some NPCs
		-- were sitting at stairs that are actually staircases
		-- TODO: Register other stair types
		--"stairs:stair_wood"
	},
	STORAGE_TYPE = {
		"default:chest",
		"default:chest_locked",
		"cottages:shelf"
	},
	FURNACE_TYPE = {
		"default:furnace",
		"default:furnace_active"
	},
	OPENABLE_TYPE = {
		-- TODO: Register fences
		"doors:door_glass_a",
		"doors:door_glass_b",
		"doors:door_obsidian_a",
		"doors:door_obsidian_b",
		"doors:door_steel_a",
		"doors:door_steel_b",
		"doors:door_wood_a",
		"doors:door_wood_b",
		"cottages:gate_open",
		"cottages:gate_closed",
		"cottages:half_door"
	},
	PLOTMARKER_TYPE = {
		"mg_villages:plotmarker",
		"advanced_npc:plotmarker"
	},
	WORKPLACE_TYPE = {
		-- TODO: Do we have an advanced_npc workplace?
		"mg_villages:mob_workplace_marker"
	}
}


npc.places.PLACE_TYPE = {
	BED = {
		PRIMARY = "bed_primary"
	},
	SITTABLE = {
		PRIMARY = "sit_primary",
		SHARED = "sit_shared"
	},
	FURNACE = {
		PRIMARY = "furnace_primary",
		SHARED = "furnace_shared"
	},
	STORAGE = {
		PRIMARY = "storage_primary",
		SHARED = "storage_shared"
	},
	OPENABLE = {
		HOME_ENTRANCE_DOOR = "home_entrance_door"
	},
	SCHEDULE = {
		TARGET = "schedule_target_pos"
	},
	WORKPLACE = {
		PRIMARY = "workplace_primary",
		TOOL = "workplace_tool"
	},
	OTHER = {
		HOME_PLOTMARKER = "home_plotmarker",
		HOME_INSIDE = "home_inside",
		HOME_OUTSIDE = "home_outside"
	}
}

function npc.places.add_shared(self, place_name, place_type, pos, access_node)
	self.places_map[place_name] = {type=place_type, pos=pos, access_node=access_node or pos, status="shared"}
end

function npc.places.add_owned(self, place_name, place_type, pos, access_node)
	self.places_map[place_name] = {type=place_type, pos=pos, access_node=access_node or pos, status="owned"}
end

function npc.places.add_owned_accessible_place(self, nodes, place_type)
	for i = 1, #nodes do
		-- Check if node has owner
		if nodes[i].owner == "" then
			-- If node has no owner, check if it is accessible
			local empty_nodes = npc.places.find_node_orthogonally(
				nodes[i].node_pos, {"air"}, 0)
			-- Check if node is accessible
			if #empty_nodes > 0 then
				-- Set owner to this NPC
				nodes[i].owner = self.npc_id
				-- Assign node to NPC
				npc.places.add_owned(self, place_type, place_type,
					nodes[i].node_pos, empty_nodes[1].pos)
				npc.log("DEBUG", "Added node at "..minetest.pos_to_string(nodes[i].node_pos)
						.." to NPC "..dump(self.npc_name))
				break
			end
		end
	end
end

-- Override flag allows to overwrite a place in the places_map.
-- The only valid use right now is for schedules - don't use this
-- anywhere else unless you have a position that changes over time.
function npc.places.add_shared_accessible_place(self, nodes, place_type, override)
	if not override then
		for i = 1, #nodes do
			-- Check if not adding same owned place
			if nodes[i].owner ~= self.npc_id then
				-- Check if it is accessible
				local empty_nodes = npc.places.find_node_orthogonally(
					nodes[i].node_pos, {"air"}, 0)
				-- Check if node is accessible
				if #empty_nodes > 0 then
					-- Assign node to NPC
					npc.places.add_shared(self, place_type..dump(i),
						place_type, nodes[i].node_pos, empty_nodes[1].pos)
				end
			end
		end
	elseif override then
		-- Note: Nodes is only *one* node in case override = true
		-- Check if it is accessible
		local empty_nodes = npc.places.find_node_orthogonally(
			nodes.node_pos, {"air"}, 0)
		-- Check if node is accessible
		if #empty_nodes > 0 then
			-- Nodes is only one node
			npc.places.add_shared(self, place_type, place_type,
				nodes.node_pos, empty_nodes[1].pos)
		end
	end
end

function npc.places.get_by_type(self, place_type)
	local result = {}
	for _, place_entry in pairs(self.places_map) do
		if place_entry.type == place_type then
			table.insert(result, place_entry)
		end
	end
	return result
end

---------------------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------------------
-- The following are utility functions that are used to operate on nodes for
-- specific conditions

-- This function searches on a squared are of the given radius
-- for nodes of the given type. The type should be npc.places.nodes
function npc.places.find_node_nearby(pos, type, radius)
	-- Determine area points
	local start_pos = {x=pos.x - radius, y=pos.y - 1, z=pos.z - radius}
	local end_pos = {x=pos.x + radius, y=pos.y + 1, z=pos.z + radius}
	-- Get nodes
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos, type)

	return nodes
end

-- TODO: This function can be improved to support a radius greater than 1.
function npc.places.find_node_orthogonally(pos, nodes, y_adjustment)
	-- Calculate orthogonal points
	local points = {}
	table.insert(points, {x=pos.x+1,y=pos.y+y_adjustment,z=pos.z})
	table.insert(points, {x=pos.x-1,y=pos.y+y_adjustment,z=pos.z})
	table.insert(points, {x=pos.x,y=pos.y+y_adjustment,z=pos.z+1})
	table.insert(points, {x=pos.x,y=pos.y+y_adjustment,z=pos.z-1})
	local result = {}
	for _,point in pairs(points) do
		local node = minetest.get_node(point)
		--minetest.log("Found node: "..dump(node)..", at pos: "..dump(point))
		for _,node_name in pairs(nodes) do
			if node.name == node_name then
				table.insert(result, {name=node.name, pos=point, param2=node.param2})
			end
		end
	end
	return result
end

-- Wrapper around minetest.find_nodes_in_area()
-- TODO: Verify if this wrapper is actually needed
function npc.places.find_node_in_area(start_pos, end_pos, type)
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos, type)
	return nodes
end

-- Function used to filter all nodes in the first floor of a building
-- If floor height isn't given, it will assume 2
-- Notice that nodes is an array of entries {node_pos={}, type={}}
function npc.places.filter_first_floor_nodes(nodes, ground_pos, floor_height)
	local height = floor_height or 2
	local result = {}
	for _,node in pairs(nodes) do
		if node.node_pos.y <= ground_pos.y + height then
			table.insert(result, node)
		end
	end
	return result
end

-- Creates an array of {pos=<node_pos>, owner=''} for managing
-- which NPC owns what
function npc.places.get_nodes_by_type(start_pos, end_pos, type)
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

-- Function to get mg_villages building data
if minetest.get_modpath("mg_villages") ~= nil then
	function npc.places.get_mg_villages_building_data(pos)
		local result = {
			village_id = "",
			plot_nr = -1,
			building_data = {},
			building_type = "",
		}
		local meta = minetest.get_meta(pos)
		result.plot_nr = meta:get_int("plot_nr")
		result.village_id = meta:get_string("village_id")

		-- Get building data
		if mg_villages.get_plot_and_building_data then
			local all_data = mg_villages.get_plot_and_building_data(result.village_id, result.plot_nr)
			result.building_data = all_data.building_data
			result.building_type = result.building_data.typ
			result["building_pos_data"] = all_data.bpos
		else
			-- Following line from mg_villages mod, protection.lua
			local btype = mg_villages.all_villages[result.village_id].to_add_data.bpos[result.plot_nr].btype
			result.building_data = mg_villages.BUILDINGS[btype]
			result.building_type = result.building_data.typ
		end
		return result
    end

    -- Pre-requisite: only run this function on mg_villages:plotmarker that has been adapted
    -- by using spawner.adapt_mg_villages_plotmarker
    function npc.places.get_all_workplaces_from_plotmarker(pos)
        local result = {}
        local meta = minetest.get_meta(pos)
        local pos_data = minetest.deserialize(meta:get_string("building_pos_data"))
        if pos_data then
        	local workplaces = pos_data.workplaces
	        if workplaces then
	            -- Insert all workplaces in this plotmarker
	            for i = 1, #workplaces do
	                table.insert(result,
	                    {
	                        workplace=workplaces[i],
	                        building_type=meta:get_string("building_type"),
							surrounding_workplace = false,
	                        node_pos= {
	                            x=workplaces[i].x,
	                            y=workplaces[i].y,
	                            z=workplaces[i].z
	                        }
	                    })
	            end
	        end
	    end
        -- Check the other plotmarkers as well
        local nearby_plotmarkers = minetest.deserialize(meta:get_string("nearby_plotmarkers"))
        if nearby_plotmarkers then
	        for i = 1, #nearby_plotmarkers do
	            if nearby_plotmarkers[i].workplaces then
	                -- Insert all workplaces in this plotmarker
	                for j = 1, #nearby_plotmarkers[i].workplaces do
	                    --minetest.log("Nearby plotmarker workplace #"..dump(j)..": "..dump(nearby_plotmarkers[i].workplaces[j]))
	                    table.insert(result, {
	                        workplace=nearby_plotmarkers[i].workplaces[j],
							building_type = nearby_plotmarkers[i].building_type,
							surrounding_workplace = true,
							node_pos = {
	                            x=nearby_plotmarkers[i].workplaces[j].x,
	                            y=nearby_plotmarkers[i].workplaces[j].y,
	                            z=nearby_plotmarkers[i].workplaces[j].z
	                        }
						})
	                end
	            end
	        end
	    end
        return result
    end
end

-- This function will search for nodes of type plotmarker and,
-- in case of being an mg_villages plotmarker, it will fetch building
-- information and include in result.
function npc.places.find_plotmarkers(pos, radius, exclude_current_pos)
	local result = {}
	local start_pos = {x=pos.x - radius, y=pos.y - 1, z=pos.z - radius}
	local end_pos = {x=pos.x + radius, y=pos.y + 1, z=pos.z + radius}
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos,
		npc.places.nodes.PLOTMARKER_TYPE)
	-- Scan nodes
	for i = 1, #nodes do
		-- Check if current plotmarker is to be excluded from the list
		local exclude = false
		if exclude_current_pos then
			if pos.x == nodes[i].x and pos.y == nodes[i].y and pos.z == nodes[i].z then
				exclude = true
			end
		end
		-- Analyze and include node if not excluded
		if not exclude then
			local node = minetest.get_node(nodes[i])
			local def = {}
			def["pos"] = nodes[i]
			def["name"] = node.name
			if node.name == "mg_villages:plotmarker" and npc.places.get_mg_villages_building_data then
				local data = npc.places.get_mg_villages_building_data(nodes[i])
				def["plot_nr"] = data.plot_nr
				def["village_id"] = data.village_id
				def["building_data"] = data.building_data
				def["building_type"] = data.building_type
				if data.building_pos_data then
					def["building_pos_data"] = data.building_pos_data
                    def["workplaces"] = data.building_pos_data.workplaces
				end
            end
            -- Add building
            --minetest.log("Adding building: "..dump(def))
			table.insert(result, def)
		end
	end
	return result
end

-- Scans an area for the supported nodes: beds, benches,
-- furnaces, storage (e.g. chests) and openable (e.g. doors).
-- Returns a table with these classifications
function npc.places.scan_area_for_usable_nodes(pos1, pos2)
	local result = {
		bed_type = {},
		sittable_type = {},
		furnace_type = {},
		storage_type = {},
		openable_type = {},
        workplace_type = {}
	}
	local start_pos, end_pos = vector.sort(pos1, pos2)

	result.bed_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.BED_TYPE)
	result.sittable_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.SITTABLE_TYPE)
	result.furnace_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.FURNACE_TYPE)
	result.storage_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.STORAGE_TYPE)
	result.openable_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.OPENABLE_TYPE)

    -- Find workplace nodes: if mg_villages:plotmarker is given a start pos, take it from there.
    -- If not, search for them.
    local node = minetest.get_node(pos1)
    if node.name == "mg_villages:plotmarker" then
        if npc.places.get_all_workplaces_from_plotmarker then
            result.workplace_type = npc.places.get_all_workplaces_from_plotmarker(pos1)
        end
    else
        -- Just search for workplace nodes
        result.workplace_type = npc.places.get_nodes_by_type(start_pos, end_pos, npc.places.nodes.WORKPLACE_TYPE)
    end

	return result
end

-- Specialized function to find doors that are an entrance to a building.
-- The definition of an entrance is:
--   The openable node with the shortest path to the plotmarker node
-- Based on this definition, other entrances aren't going to be used
-- by the NPC to get into the building
function npc.places.find_entrance_from_openable_nodes(all_openable_nodes, marker_pos)
	local result
	local openable_nodes = {}
	local min = 100

	-- Filter out all other openable nodes except MTG doors.
	-- Why? For supported village types (which are: medieval, nore
	-- and logcabin) all buildings use, as the main entrance,
	-- a MTG door. Some medieval building have "half_doors" (like farms)
	-- which NPCs love to confuse with the right building entrance.
	for i = 1, #all_openable_nodes do
		local name = minetest.get_node(all_openable_nodes[i].node_pos).name
		local doors_st, _ = string.find(name, "doors:")
		if doors_st ~= nil then
			table.insert(openable_nodes, all_openable_nodes[i])
		end
	end


	for i = 1, #openable_nodes do

		local open_pos = openable_nodes[i].node_pos

		-- Get node name - check if this node is a 'door'. The way to check
		-- is by explicitly checking for 'door' string
		local name = minetest.get_node(open_pos).name
		local start_i, _ = string.find(name, "door")

		if start_i ~= nil then
			-- Define start and end pos
			local start_pos = {x=open_pos.x, y=open_pos.y, z=open_pos.z}
			local end_pos = {x=marker_pos.x, y=marker_pos.y, z=marker_pos.z}

			-- minetest.log("Openable node pos: "..minetest.pos_to_string(open_pos))
			-- minetest.log("Plotmarker node pos: "..minetest.pos_to_string(marker_pos))

			-- Find path from the openable node to the plotmarker
			--local path = pathfinder.find_path(start_pos, end_pos, 20, {})
			local entity = {}
			entity.collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20}
			--minetest.log("Start pos: "..minetest.pos_to_string(start_pos))
			--minetest.log("End pos: "..minetest.pos_to_string(end_pos))
			local path = npc.pathfinder.find_path(start_pos, end_pos, entity, false)
			--minetest.log("Found path: "..dump(path))
			if path ~= nil then
				--minetest.log("Path distance: "..dump(#path))
				-- Check if path length is less than the minimum found so far
				if #path < min then
					-- Set min to path length and the result to the currently found node
					min = #path
					result = openable_nodes[i]
				else
					-- Specific check to prefer mtg's doors to cottages' doors.
					-- The reason? Sometimes a cottages' door could be closer to the
					-- plotmarker, but not being the building entrance. MTG doors
					-- are usually the entrance... so yes, hackity hack.
					-- Get the name of the currently mininum-distance door
					local min_node_name = minetest.get_node(result.node_pos).name
					-- Check if this is a door from MTG's doors.
					local doors_st, _ = string.find(name, "doors:")
					-- Check if min-distance door is a cottages door
					-- while we have a MTG door
					if min_node_name == "cottages:half_door" and doors_st ~= nil then
						--minetest.log("Assigned new door...")
						min = #path
						result = openable_nodes[i]
					end
				end
			else
				npc.log("ERROR", "Path not found to marker from "..minetest.pos_to_string(start_pos))
			end
		end
	end
	-- Return result
	return result
end

-- Specialized function to find all sittable nodes supported by the
-- mod, namely default stairs and cottages' benches. Since not all
-- stairs nodes placed aren't meant to simulate benches, this function
-- is necessary in order to find stairs that are meant to be benches.
function npc.places.find_sittable_nodes_nearby(pos, radius)
	local result = {}
	-- Try to find sittable nodes
	local nodes = npc.places.find_node_nearby(pos, npc.places.nodes.SITTABLE, radius)
	-- Highly unorthodox check for emptinnes
	if nodes[1] ~= nil then
		for i = 1, #nodes do
			-- Get node name, try to avoid using the staircase check if not a stair node
			local node = minetest.get_node(nodes[i])
			local i1, _ = string.find(node.name, "stairs:")
			if i1 ~= nil then
				if npc.places.is_in_staircase(nodes[i]) < 1 then
					table.insert(result, nodes[i])
				end
			else
				-- Add node as it is sittable
				table.insert(result, nodes[i])
			end
		end
	end
	-- Return sittable nodes
	return result
end

-- Specialized function to find sittable stairs: stairs that don't
-- have any other stair above them. Only stairs using the default
-- stairs mod are supported for now.
-- Receives a position of a stair node.

npc.places.staircase = {
	none = 0,
	bottom = 1,
	middle = 2,
	top = 3
}

function npc.places.is_in_staircase(pos)
	local node = minetest.get_node(pos)
	-- Verify node is actually from default stairs mod
	local p1, _ = string.find(node.name, "stairs:")
	if p1 ~= nil then
		-- Calculate the logical position to the lower and upper stairs node location
		local up_x_adj, up_z_adj = 0, 0
		local lo_x_adj, lo_z_adj = 0, 0
		if node.param2 == 1 then
			up_z_adj = -1
			lo_z_adj = 1
		elseif node.param2 == 2 then
			up_z_adj = 1
			lo_z_adj = -1
		elseif node.param2 == 3 then
			up_x_adj = -1
			lo_x_adj = 1
		elseif node.param2 == 4 then
			up_x_adj = 1
			lo_x_adj = -1
		else
			-- This is not a staircase
			return false
		end

		-- Calculate upper and lower position
		local upper_pos = {x=pos.x + up_x_adj, y=pos.y + 1, z=pos.z + up_z_adj}
		local lower_pos = {x=pos.x + lo_x_adj, y=pos.y - 1, z=pos.z + lo_z_adj}
		-- Get next node
		local upper_node = minetest.get_node(upper_pos)
		local lower_node = minetest.get_node(lower_pos)
		--minetest.log("Next node: "..dump(upper_pos))
		-- Check if next node is also a stairs node
		local up_p1, _ = string.find(upper_node.name, "stairs:")
		local lo_p1, _ = string.find(lower_node.name, "stairs:")

		if up_p1 ~= nil then
			-- By default, think this is bottom of staircase.
			local result = npc.places.staircase.bottom
			-- Try downwards now
			if lo_p1 ~= nil then
				result = npc.places.staircase.middle
			end
			return result
		else
			-- Check if there is a staircase downwards
			if lo_p1 ~= nil then
				return npc.places.staircase.top
			else
				return npc.places.staircase.none
			end
		end
	end
	-- This is not a stairs node
	return nil
end

-- Specialized function to find the node position right behind
-- a door. Used to make NPCs enter buildings.
function npc.places.find_node_behind_door(door_pos)
	local door = minetest.get_node(door_pos)
	if door.param2 == 0 then
		-- Looking south
		return {x=door_pos.x, y=door_pos.y, z=door_pos.z + 1}
	elseif door.param2 == 1 then
		-- Looking east
		return {x=door_pos.x + 1, y=door_pos.y, z=door_pos.z}
	elseif door.param2 == 2 then
		-- Looking north
		return {x=door_pos.x, y=door_pos.y, z=door_pos.z - 1}
		-- Looking west
	elseif door.param2 == 3 then
		return {x=door_pos.x - 1, y=door_pos.y, z=door_pos.z}
	end
end

-- Specialized function to find the node position right in
-- front of a door. Used to make NPCs exit buildings.
function npc.places.find_node_in_front_of_door(door_pos)
	local door = minetest.get_node(door_pos)
	--minetest.log("Param2 of door: "..dump(door.param2))
	if door.param2 == 0 then
		-- Looking south
		return {x=door_pos.x, y=door_pos.y, z=door_pos.z - 1}
	elseif door.param2 == 1 then
		-- Looking east
		return {x=door_pos.x - 1, y=door_pos.y, z=door_pos.z}
	elseif door.param2 == 2 then
		-- Looking north
		return {x=door_pos.x, y=door_pos.y, z=door_pos.z + 1}
	elseif door.param2 == 3 then
		-- Looking west
		return {x=door_pos.x + 1, y=door_pos.y, z=door_pos.z}
	end
end
