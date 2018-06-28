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

-- Public API
npc.locations = {}

-- Function to register nodes
-- Categories are utilized to categorize nodes by type, example beds,
-- furnaces, etc. Sub-categories give more particular categorization to
-- beds in terms of how the NPC uses them
function npc.locations.register_node(node_name, category, sub_category)
	-- Check category, if it doesn't exists, create it
	if npc.locations.data.categories[category] == nil then
		-- Create category name
		npc.locations.data.categories[category] = category
		npc.locations.data[category] = {}
	end
	-- Check sub-category and create it if necessary
	if npc.locations.data[category][sub_category] == nil then
		-- Create sub category
		npc.locations.data[category][sub_category] = sub_category
	end
	-- Add node
	npc.locations.nodes[category][#npc.locations.nodes[category] + 1] = node_name
end

-- Default set of registered nodes
npc.locations.nodes = {
	bed = {
		"beds:bed_bottom",
		"beds:fancy_bed_bottom",
		"cottages:bed_foot",
		"cottages:straw_mat",
		"cottages:sleeping_mat"
	},
	sittable = {
		"cottages:bench",
		-- currently commented out since some npcs
		-- were sitting at stairs that are actually staircases
		-- TODO: register other stair types
		--"stairs:stair_wood"
	},
	storage = {
		"default:chest",
		"default:chest_locked",
		"cottages:shelf"
	},
	furnace = {
		"default:furnace",
		"default:furnace_active"
	},
	openable = {
		-- TODO: register fences
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
	plotmarker = {
		"mg_villages:plotmarker",
		"advanced_npc:plotmarker"
	},
	workplace = {
		-- TODO: do we have an advanced_npc workplace?
		"mg_villages:mob_workplace_marker",
		"advanced_npc:workplace_marker"
	}
}

-- Spawner function assign_places can also take a generic categories, and specially
-- process the hardcoded ones.
npc.locations.data = {
	categories = {
		bed = "bed",
		sittable = "sittable",
		furnace = "furnace",
		storage = "storage",
		openable = "openable",
		schedule = "schedule",
		calculated = "calculated",
		workplace = "workplace",
		other = "other"
	},
	bed = {
		primary = "bed_primary"
	},
	sittable = {
		primary = "sit_primary",
		shared = "sit_shared"
	},
	furnace = {
		primary = "furnace_primary",
		shared = "furnace_shared"
	},
	storage = {
		primary = "storage_primary",
		shared = "storage_shared"
	},
	openable = {
		home_entrance_door = "home_entrance_door",
		room_entrance_door = "room_entrance_door"
	},
	schedule = {
		target = "schedule_target_pos"
	},
	calculated = {
		target = "calculated_target_pos"
	},
	workplace = {
		primary = "workplace_primary",
		tool = "workplace_tool"
	},
	other = {
		home_plotmarker = "home_plotmarker",
		home_inside = "home_inside",
		home_outside = "home_outside",
		room_inside = "room_inside",
		room_outside = "room_outside"
	},
	is_primary = function(place_type)
		local p1,p2 = string.find(place_type, "primary")
		return p1 ~= nil
	end,
	-- Only works for place types where there is a "primary" and a "shared"
	get_alternative = function(place_category, place_type)
		local result = {}
		local place_types = npc.locations.data[place_category]
		-- Determine search type
		local search_shared = false
		if npc.locations.data.is_primary(place_type) then
			search_shared = true
		end
		for key,place_type in pairs(place_types) do
			if search_shared == true then
				if npc.locations.data.is_primary(place_type) == false then
					return place_type
				end
			else
				if npc.locations.data.is_primary(place_type) == true then
					return place_type
				end
			end
		end
	end
}

npc.locations.USE_STATE = {
	USED = "true",
	NOT_USED = "false"
}

function npc.locations.add_shared(self, place_name, place_type, pos, access_node)
	-- Set metadata of node
	local meta = minetest.get_meta(pos)
	if not meta:get_string("advanced_npc:used") then
		meta:set_string("advanced_npc:used", npc.locations.USE_STATE.NOT_USED)
	end
	meta:set_string("advanced_npc:owner", "")
	-- This *should* avoid lags
	meta:mark_as_private({"advanced_npc:used", "advanced_npc:owner"})
	self.places_map[place_name] = {type=place_type, pos=pos, access_node=access_node or pos, status="shared"}
end

function npc.locations.add_owned(self, place_name, place_type, pos, access_node)
	-- Set metadata of node
	local meta = minetest.get_meta(pos)
	if not meta:get_string("advanced_npc:used") then
		meta:set_string("advanced_npc:used", npc.locations.USE_STATE.NOT_USED)
	end
	meta:set_string("advanced_npc:owner", self.npc_id)
	-- This *should* avoid lags
	meta:mark_as_private({"advanced_npc:used", "advanced_npc:owner"})
	self.places_map[place_name] = {type=place_type, pos=pos, access_node=access_node or pos, status="owned"}
end

function npc.locations.add_owned_accessible_place(self, nodes, place_type, walkables)
	for i = 1, #nodes do
		-- Check if node has owner
		local owner = minetest.get_meta(nodes[i].node_pos):get_string("advanced_npc:owner")
		--minetest.log("Condition: "..dump(owner == ""))
		if owner == "" then
			-- If node has no owner, check if it is accessible
			local empty_nodes = npc.locations.find_orthogonal_accessible_node(
				nodes[i].node_pos, nil, 0, true, walkables)
			-- Check if node is accessible
			if #empty_nodes > 0 then
				-- Set owner to this NPC
				nodes[i].owner = self.npc_id
				-- Assign node to NPC
				npc.locations.add_owned(self, place_type, place_type,
					nodes[i].node_pos, empty_nodes[1].pos)
				npc.log("DEBUG", "Added node at "..minetest.pos_to_string(nodes[i].node_pos)
						.." to NPC "..dump(self.npc_name))
				-- Return node
				return nodes[i]
			end
		end
	end
end

-- Override flag allows to overwrite a place in the places_map.
-- The only valid use right now is for schedules - don't use this
-- anywhere else unless you have a position that changes over time.
function npc.locations.add_shared_accessible_place(self, nodes, place_type, override, walkables)

	if not override or (override and override == false) then
		for i = 1, #nodes do
			-- Check if not adding same owned place
			if nodes[i].owner ~= self.npc_id then
				-- Check if it is accessible
				local empty_nodes = npc.locations.find_orthogonal_accessible_node(
					nodes[i].node_pos, nil, 0, true, walkables)
				-- Check if node is accessible
				if #empty_nodes > 0 then
					-- Assign node to NPC
					npc.locations.add_shared(self, place_type..dump(i),
						place_type, nodes[i].node_pos, empty_nodes[1].pos)
				else
					npc.log("WARNING", "Found non-accessible place at pos: "..minetest.pos_to_string(nodes[i].node_pos))
				end
			end
		end
	elseif override == true then
		-- Note: Nodes is only *one* node in case override = true
		-- Check if it is accessible
		local empty_nodes = npc.locations.find_orthogonal_accessible_node(
			nodes.node_pos, nil, 0, true, walkables)
		-- Check if node is accessible
		if #empty_nodes > 0 then
			-- Nodes is only one node
			npc.locations.add_shared(self, place_type, place_type, nodes.node_pos, empty_nodes[1].pos)
		end
	end
end

function npc.locations.mark_place_used(pos, value)
	local meta = minetest.get_meta(pos)
	local used = meta:get_string("advanced_npc:used")
	if value == used then
		npc.log("WARNING", "Attempted to set 'used' property of node at "
				..minetest.pos_to_string(pos).." to the same value: '"..dump(value).."'")
		return false
	else
		meta:set_string("advanced_npc:used", value)
		npc.log("DEBUG", "'Used' value at pos "..minetest.pos_to_string(pos)..": "..dump(meta:get_string("advanced_npc:used")))
		return true
	end
end

-- This function is to find an alternative place if the original is
-- not usable. If the original place is a "primary" place, it will
-- try to find a "shared" place. If it is a "shared" place, it will try
-- to find a "primary" place. If none is found, it retuns the given type.
function npc.locations.find_unused_place(self, place_category, place_type, original_place)
	local result = {}
	-- Check if node is being used
	local meta = minetest.get_meta(original_place.pos)
	local used = meta:get_string("advanced_npc:used")
	if used == npc.locations.USE_STATE.USED then
		-- Node is being used, try to find alternative
		local alternative_place_type = npc.locations.data.get_alternative(place_category, place_type)
		--minetest.log("Alternative place type: "..dump(alternative_place_type))
		local alternative_places = npc.locations.get_by_type(self, alternative_place_type)
		--minetest.log("Alternatives: "..dump(alternative_places))
		for i = 1, #alternative_places do
			meta = minetest.get_meta(alternative_places[i].pos)
			local used = meta:get_string("advanced_npc:used")
			if used == npc.locations.USE_STATE.NOT_USED then
				return alternative_places[i]
			end
		end
	else
		result = original_place
	end
	return result
end

function npc.locations.get_by_type(self, place_type, exact_match)
	local result = {}
	for _, place_entry in pairs(self.places_map) do
		--minetest.log("Looking for: "..dump(place_type)..", in: "..dump(place_entry.type))
		local s, _ = string.find(place_entry.type, place_type)
		if s ~= nil then
			--minetest.log("Found: "..dump(place_entry))
			result[#result + 1] = place_entry
		end
	end
	--minetest.log("Returning: "..dump(result))
	return result
end

---------------------------------------------------------------------------------------
-- Utility functions
---------------------------------------------------------------------------------------
-- The following are utility functions that are used to operate on nodes for
-- specific conditions

-- This func
function npc.locations.is_walkable(node_name)
	return node_name == "air"
		-- Any walkable node except fences
		or (minetest.registered_nodes[node_name].walkable == false
			and minetest.registered_nodes[node_name].groups.fence ~= 1)
		-- Farming plants
		or minetest.registered_nodes[node_name].groups.plant == 1
end

-- This function searches on a squared are of the given radius
-- for nodes of the given type. The type should be npc.locations.nodes
function npc.locations.find_node_nearby(pos, type, radius, vertical_range_limit)
	local y_offset = radius
	if vertical_range_limit then
		y_offset = vertical_range_limit
	end
	-- Determine area points
	local start_pos = {x=pos.x - radius, y=pos.y - y_offset, z=pos.z - radius}
	local end_pos = {x=pos.x + radius, y=pos.y + y_offset, z=pos.z + radius}
	-- Get nodes
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos, type)

	return nodes
end

-- TODO: This function can be improved to support a radius greater than 1.
function npc.locations.find_node_orthogonally(pos, nodes, y_adjustment)
	-- Call the more generic function with appropriate params
	return npc.locations.find_orthogonal_accessible_node(pos, nodes, y_adjustment, nil, nil)
end

-- TODO: This function can be improved to support a radius greater than 1.
function npc.locations.find_orthogonal_accessible_node(pos, nodes, y_adjustment, include_walkables, extra_walkables)
	-- Calculate orthogonal points
	local points = {}
	points[#points + 1] = {x=pos.x+1,y=pos.y+y_adjustment,z=pos.z}
	points[#points + 1] = {x=pos.x-1,y=pos.y+y_adjustment,z=pos.z}
	points[#points + 1] = {x=pos.x,y=pos.y+y_adjustment,z=pos.z+1}
	points[#points + 1] = {x=pos.x,y=pos.y+y_adjustment,z=pos.z-1}
	local result = {}
	for _,point in pairs(points) do
		local node = minetest.get_node(point)
		-- Search for specific node names
		if nodes then
			for _,node_name in pairs(nodes) do
				if node.name == node_name then
					table.insert(result, {name=node.name, pos=point, param2=node.param2})
				end
			end
		else
			-- Search for air, walkable nodes, or any node availble in the extra_walkables array
			if node.name == "air"
					or (include_walkables == true
					and minetest.registered_nodes[node.name].walkable == false
					and minetest.registered_nodes[node.name].groups.fence ~= 1)
					or (extra_walkables and npc.utils.array_contains(extra_walkables, node.name)) then
				result[#result + 1] = {name=node.name, pos=point, param2=node.param2}
			end
		end
	end
	return result
end


-- Wrapper around minetest.find_nodes_in_area()
-- TODO: Verify if this wrapper is actually needed
function npc.locations.find_node_in_area(start_pos, end_pos, type)
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos, type)
	return nodes
end

-- Function used to filter all nodes in the first floor of a building
-- If floor height isn't given, it will assume 2
-- Notice that nodes is an array of entries {node_pos={}, type={}}
function npc.locations.filter_first_floor_nodes(nodes, ground_pos, floor_height)
	local height = floor_height or 2
	local result = {}
	for _,node in pairs(nodes) do
		if node.node_pos.y <= ground_pos.y + height then
			result[#result + 1] = node
		end
	end
	return result
end

-- Creates an array of {pos=<node_pos>, owner=''} for managing
-- which NPC owns what
function npc.locations.get_nodes_by_type(start_pos, end_pos, type)
	local result = {}
	local nodes = npc.locations.find_node_in_area(start_pos, end_pos, type)
	--minetest.log("Found "..dump(#nodes).." nodes of type: "..dump(type))
	for _,node_pos in pairs(nodes) do
		local entry = {}
		entry["node_pos"] = node_pos
		entry["owner"] = ''
		result[#result + 1] = entry
	end
	return result
end

-- Function to get mg_villages building data
if minetest.get_modpath("mg_villages") ~= nil then
	function npc.locations.get_mg_villages_building_data(pos)
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
			if all_data then
				result.building_data = all_data.building_data
				result.building_type = result.building_data.typ
				result["building_pos_data"] = all_data.bpos
			end
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
	function npc.locations.get_all_workplaces_from_plotmarker(pos)
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
		npc.log("DEBUG", "Nearby plotmarkers: "..dump(nearby_plotmarkers))
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
function npc.locations.find_plotmarkers(pos, radius, exclude_current_pos)
	local result = {}
	local start_pos = {x=pos.x - radius, y=pos.y - 1, z=pos.z - radius}
	local end_pos = {x=pos.x + radius, y=pos.y + 1, z=pos.z + radius}
	local nodes = minetest.find_nodes_in_area(start_pos, end_pos,
		npc.locations.nodes.plotmarker)
	npc.log("INFO", "Found "..dump(#nodes).." plotmarkers")
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
			if node.name == "mg_villages:plotmarker" and npc.locations.get_mg_villages_building_data then
				local data = npc.locations.get_mg_villages_building_data(nodes[i])
				def["plot_nr"] = data.plot_nr
				def["village_id"] = data.village_id
				--def["building_data"] = data.building_data
				def["building_type"] = data.building_type
				npc.log("INFO", "["..dump(data.building_type).."]")
				if data.building_pos_data then
					def["building_pos_data"] = data.building_pos_data
					if next(data.building_pos_data.workplaces) ~= nil then
						def["workplaces"] = data.building_pos_data.workplaces
					end
				end
				if data.workplaces and next(data.workplaces) ~= nil then
					def["workplaces"] = data.workplaces
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
function npc.locations.scan_area_for_usable_nodes(pos1, pos2)
	minetest.log("Bed Nodes: "..dump(npc.locations.nodes.bed))
	local result = {
		bed_type = {},
		sittable_type = {},
		furnace_type = {},
		storage_type = {},
		openable_type = {},
		workplace_type = {}
	}
	local start_pos, end_pos = vector.sort(pos1, pos2)

	result.bed_type = npc.locations.get_nodes_by_type(start_pos, end_pos, npc.locations.nodes.bed)
	result.sittable_type = npc.locations.get_nodes_by_type(start_pos, end_pos, npc.locations.nodes.sittable)
	result.furnace_type = npc.locations.get_nodes_by_type(start_pos, end_pos, npc.locations.nodes.furnace)
	result.storage_type = npc.locations.get_nodes_by_type(start_pos, end_pos, npc.locations.nodes.storage)
	result.openable_type = npc.locations.get_nodes_by_type(start_pos, end_pos, npc.locations.nodes.openable)

	-- Find workplace nodes: if mg_villages:plotmarker is given as start pos, take it from there.
	-- If not, search for them.
	local node = minetest.get_node(pos1)
	if node.name == "mg_villages:plotmarker" then
		if npc.locations.get_all_workplaces_from_plotmarker then
			result.workplace_type = npc.locations.get_all_workplaces_from_plotmarker(pos1)
		end
	else
		-- Just search for workplace nodes
		-- The search radius is increased by 2
		result.workplace_type = npc.locations.get_nodes_by_type(
			{x=start_pos.x-20, y=start_pos.y, z=start_pos.z-20},
			{x=end_pos.x+20, y=end_pos.y, z=end_pos.z+20},
			npc.locations.nodes.workplace)
		-- Find out building type and add it to the result
		for i = 1, #result.workplace_type do
			local meta = minetest.get_meta(result.workplace_type[i].node_pos)
			local building_type = meta:get_string("building_type") or "none"
			local surrounding_workplace = meta:get_string("surrounding_workplace") or "false"
			result.workplace_type[i]["surrounding_workplace"] = minetest.is_yes(surrounding_workplace)
			result.workplace_type[i]["building_type"] = building_type
		end
	end

	return result
end

-- Helper function to clear metadata in an array of nodes
-- Metadata that will be cleared is:
--  advanced_npc:used
--  advanced_npc:owner
local function clear_metadata(nodes)
	local c = 0
	for i = 1, #nodes do
		local meta = minetest.get_meta(nodes[i].node_pos)
		meta:set_string("advanced_npc:owner", "")
		meta:set_string("advanced_npc:used", npc.locations.USE_STATE.NOT_USED)
		c = c + 1
	end
	return c
end

function npc.locations.clear_metadata_usable_nodes_in_area(node_data)
	local count = 0
    if node_data then
        count = count + clear_metadata(node_data.bed_type)
        count = count + clear_metadata(node_data.sittable_type)
        count = count + clear_metadata(node_data.furnace_type)
        count = count + clear_metadata(node_data.storage_type)
        count = count + clear_metadata(node_data.openable_type)
        -- Clear workplace nodes
        if node_data.workplace_type then
            for i = 1, #node_data.workplace_type do
                local meta = minetest.get_meta(node_data.workplace_type[i].node_pos)
                meta:set_string("work_data", nil)
                count = count + 1
            end
        end
    end
	return count
end

local function get_decorated_path(start_pos, end_pos)
	local entity = {}
	entity.collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20}
	local path = npc.pathfinder.find_path(start_pos, end_pos, entity, true)
	return path
end

function npc.locations.find_building_entrance(bed_nodes, marker_pos)
	-- Exit if no bed nodes given
	if bed_nodes == nil or (bed_nodes and #bed_nodes == 0) then
		return
	end

	-- Iterate through bed nodes to try and find an entrance
	for i = 1, #bed_nodes do

		-- Initialize positions
		local start_pos = bed_nodes[i].node_pos
		local end_pos = {x=marker_pos.x, y=marker_pos.y, z=marker_pos.z}
		npc.log("INFO", "Trying to find path from "..minetest.pos_to_string(start_pos).." to "..minetest.pos_to_string(end_pos))

		-- Find path from the bed node to the plotmarker
		local decorated_path = get_decorated_path(start_pos, end_pos)

		-- Find building entrance, traverse path backwards and return first node that is openable
		if decorated_path then
			for j = #decorated_path, 1, -1 do
				if decorated_path[j].type == npc.pathfinder.node_types.openable then
					local result = {
						door = vector.round(decorated_path[j].pos),
						inside = vector.round(decorated_path[j-1].pos),
						outside = vector.round(decorated_path[j+1].pos)
					}
					return result
				end
			end
		end

		npc.log("INFO", "Attempt "..dump(i).." of "..dump(#bed_nodes).." of finding entrance from bed failed.")
	end
end

function npc.locations.find_bedroom_entrance(bed_node, marker_pos)
	local start_pos = bed_node.node_pos
	local end_pos = {x=marker_pos.x, y=marker_pos.y, z=marker_pos.z }
	-- Find path from the bed node to the plotmarker
	local decorated_path = get_decorated_path(start_pos, end_pos)
	--minetest.log("Decorated path: "..dump(decorated_path))
	-- Find building entrance, traverse path forward and return first node that is openable
	for i = 1, #decorated_path do
		if decorated_path[i].type == npc.pathfinder.node_types.openable then
			return {
				door = vector.floor(decorated_path[i].pos),
				inside = vector.floor(decorated_path[i-1].pos),
				outside = vector.floor(decorated_path[i+1].pos)
			}
		end
	end
end


--------------------------------------------------------------------
-- WARNING! Code below here DOESN'T WORKS correctly... don't use! --
--------------------------------------------------------------------

-- Specialized function to find all sittable nodes supported by the
-- mod, namely default stairs and cottages' benches. Since not all
-- stairs nodes placed aren't meant to simulate benches, this function
-- is necessary in order to find stairs that are meant to be benches.
function npc.locations.find_sittable_nodes_nearby(pos, radius)
	local result = {}
	-- Try to find sittable nodes
	local nodes = npc.locations.find_node_nearby(pos, npc.locations.nodes.sittable, radius)
	-- Highly unorthodox check for emptinnes
	if nodes[1] ~= nil then
		for i = 1, #nodes do
			-- Get node name, try to avoid using the staircase check if not a stair node
			local node = minetest.get_node(nodes[i])
			local i1, _ = string.find(node.name, "stairs:")
			if i1 ~= nil then
				if npc.locations.is_in_staircase(nodes[i]) < 1 then
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

npc.locations.staircase = {
	none = 0,
	bottom = 1,
	middle = 2,
	top = 3
}

function npc.locations.is_in_staircase(pos)
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
			local result = npc.locations.staircase.bottom
			-- Try downwards now
			if lo_p1 ~= nil then
				result = npc.locations.staircase.middle
			end
			return result
		else
			-- Check if there is a staircase downwards
			if lo_p1 ~= nil then
				return npc.locations.staircase.top
			else
				return npc.locations.staircase.none
			end
		end
	end
	-- This is not a stairs node
	return nil
end

-- WARNING: DEPRECATED
-- Specialized function to find the node position right behind
-- a door. Used to make NPCs enter buildings.
function npc.locations.find_node_in_front_and_behind_door(door_pos)
	local door = minetest.get_node(door_pos)
	local scan_pos = {
		{x=door_pos.x + 1, y=door_pos.y, z=door_pos.z},
		{x=door_pos.x - 1, y=door_pos.y, z=door_pos.z},
		{x=door_pos.x, y=door_pos.y, z=door_pos.z + 1},
		{x=door_pos.x, y=door_pos.y, z=door_pos.z - 1}
	}

	local facedir_vector = minetest.facedir_to_dir(door.param2)
	local back_pos = vector.add(door_pos, facedir_vector)
	local back_node = minetest.get_node(back_pos)
	local front_pos
	if back_node.name == "air" or minetest.registered_nodes[back_node.name].walkable == false then
		-- Door is closed, so back_pos is the actual behind position.
		-- Calculate front node
		front_pos = vector.add(door_pos, vector.multiply(facedir_vector, -1))
	else
		-- Door is open, need to find the front and back pos
		facedir_vector = minetest.facedir_to_dir((door.param2 + 2) % 4)
		back_pos = vector.add(door_pos, facedir_vector)
		front_pos = vector.add(door_pos, vector.multiply(facedir_vector, -1))
	end
	return back_pos, front_pos
end