-- Pathfinding code by MarkBu, original can be found here:
-- https://github.com/MarkuBu/pathfinder
--
-- Modifications by Zorman2000
-- This version is slightly modified to use another "walkable" function,
-- plus add a "decorating" path function which allows to know the type
-- of nodes in the path.
---------------------------------------------------------------------------------------
-- Pathfinding functionality
---------------------------------------------------------------------------------------

npc.pathfinder = {}

local pathfinder = {}

npc.pathfinder.node_types = {
	start = 0,
	goal = 1,
	walkable = 2,
	openable = 3,
	non_walkable = 4
}

npc.pathfinder.nodes = {
	openable_prefix = {
		"doors:",
		"cottages:gate",
		"cottages:half_door"
	}
}

-- This function is used to determine if a node is walkable
-- or openable, in which case is good to use when finding a path
function pathfinder.is_good_node(node, exceptions)
	--local function is_good_node(node, exceptions)
	-- Is openable is to support doors, fence gates and other
	-- doors from other mods. Currently, default doors, gates
	-- and cottages doors are supported.
	local is_openable = false
	for _,node_prefix in pairs(npc.pathfinder.nodes.openable_prefix) do
		local start_i,end_i = string.find(node.name, node_prefix)
		if start_i ~= nil then
			is_openable = true
			break
		end
	end
	if node ~= nil and node.name ~= nil and not minetest.registered_nodes[node.name].walkable then
		return npc.pathfinder.node_types.walkable
	elseif is_openable then
		return npc.pathfinder.node_types.openable
	else
		for i = 1, #exceptions do
			if node.name == exceptions[i] then
				return npc.pathfinder.node_types.walkable
			end
		end
		return npc.pathfinder.node_types.non_walkable
	end
end

function pathfinder.get_decorated_path(path)
	-- Get details from path nodes
	local path_detail = {}
	for i = 1, #path do
		local node = minetest.get_node(path[i])
		table.insert(path_detail, {pos={x=path[i].x, y=path[i].y-0.5, z=path[i].z},
			type=pathfinder.is_good_node(node, {})})
	end

	npc.log("DEBUG", "Detailed path: "..dump(path_detail))
	return path_detail
end

function npc.pathfinder.find_path(start_pos, end_pos, entity, decorate_path)
	local path = pathfinder.find_path(start_pos, end_pos, entity)
	if path then
		if decorate_path then
			path = pathfinder.get_decorated_path(path)
		end
	else
		npc.log("ERROR", "Couldn't find path from "..minetest.pos_to_string(start_pos)
				.." to "..minetest.pos_to_string(end_pos))
	end
	return path
end

-- From this point onwards is MarkBu's original pathfinder code,
-- except for the "walkable" function, which is modified by Zorman2000
-- to include doors and other "walkable" nodes.
-- The version here is exactly this:
-- https://github.com/MarkuBu/pathfinder/commit/ca0b433bf5efde5da545b11b2691fa7f7e53dc30

--[[
minetest.get_content_id(name)
minetest.registered_nodes
minetest.get_name_from_content_id(id)
local ivm = a:index(pos.x, pos.y, pos.z)
local ivm = a:indexp(pos)
minetest.hash_node_position({x=,y=,z=})
minetest.get_position_from_hash(hash)

start_index, target_index, current_index
^ Hash of position

current_value
^ {int:hCost, int:gCost, int:fCost, hash:parent, vect:pos}
]]--

local openSet = {}
local closedSet = {}

local function get_distance(start_pos, end_pos)
	local distX = math.abs(start_pos.x - end_pos.x)
	local distZ = math.abs(start_pos.z - end_pos.z)

	if distX > distZ then
		return 14 * distZ + 10 * (distX - distZ)
	else
		return 14 * distX + 10 * (distZ - distX)
	end
end

local function get_distance_to_neighbor(start_pos, end_pos)
	local distX = math.abs(start_pos.x - end_pos.x)
	local distY = math.abs(start_pos.y - end_pos.y)
	local distZ = math.abs(start_pos.z - end_pos.z)

	if distX > distZ then
		return (14 * distZ + 10 * (distX - distZ)) * (distY + 1)
	else
		return (14 * distX + 10 * (distZ - distX)) * (distY + 1)
	end
end

-- This function is used to determine if a node is walkable
-- or openable, in which case is good to use when finding a path
local function walkable(node, exceptions)
	local exceptions = exceptions or {}
	-- Is openable is to support doors, fence gates and other
	-- doors from other mods. Currently, default doors, gates
	-- and cottages doors are supported.
	--minetest.log("Is good node: "..dump(node))
	local is_openable = false
	for _,node_prefix in pairs(npc.pathfinder.nodes.openable_prefix) do
		local start_i,end_i = string.find(node.name, node_prefix)
		if start_i ~= nil then
			is_openable = true
			break
		end
	end
	-- Detect mg_villages ceilings usage of thin wood nodeboxes
	-- TODO: Improve
	local is_mg_villages_ceiling = false
	if node.name == "cottages:wood_flat" then
		is_mg_villages_ceiling = true
	end
	if node ~= nil
			and node.name ~= nil
			and node.name ~= "ignore"
			and minetest.registered_nodes[node.name]
			and not minetest.registered_nodes[node.name].walkable then
		return false
	elseif is_openable then
		return false
	elseif is_mg_villages_ceiling then
		return false
	else
		for i = 1, #exceptions do
			if node.name == exceptions[i] then
				return false
			end
		end
		return true
	end
end

local function check_clearance(cpos, x, z, height)
	for i = 1, height do
		local n_name = minetest.get_node({x = cpos.x + x, y = cpos.y + i, z = cpos.z + z}).name
		local c_name = minetest.get_node({x = cpos.x, y = cpos.y + i, z = cpos.z}).name
		--~ print(i, n_name, c_name)
		if walkable(n_name) or walkable(c_name) then
			return false
		end
	end
	return true
end

local function get_neighbor_ground_level(pos, jump_height, fall_height)
	local node = minetest.get_node(pos)
	local height = 0
	if walkable(node) then
		repeat
			height = height + 1
			if height > jump_height then
				return nil
			end
			pos.y = pos.y + 1
			node = minetest.get_node(pos)
		until not walkable(node)
		return pos
	else
		repeat
			height = height + 1
			if height > fall_height then
				return nil
			end
			pos.y = pos.y - 1
			node = minetest.get_node(pos)
		until walkable(node)
		return {x = pos.x, y = pos.y + 1, z = pos.z}
	end
end

function pathfinder.find_path(pos, endpos, entity)
	local start_index = minetest.hash_node_position(pos)
	local target_index = minetest.hash_node_position(endpos)
	local count = 1

	openSet = {}
	closedSet = {}

	local h_start = get_distance(pos, endpos)
	openSet[start_index] = {hCost = h_start, gCost = 0, fCost = h_start, parent = nil, pos = pos}

	-- Entity values
	local entity_height = math.ceil(entity.collisionbox[5] - entity.collisionbox[2])
	local entity_fear_height = entity.fear_height or 2
	local entity_jump_height = entity.jump_height or 1

	repeat
		local current_index
		local current_values

		-- Get one index as reference from openSet
		for i, v in pairs(openSet) do
			current_index = i
			current_values = v
			break
		end

		-- Search for lowest fCost
		for i, v in pairs(openSet) do
			if v.fCost < openSet[current_index].fCost or v.fCost == current_values.fCost and v.hCost < current_values.hCost then
				current_index = i
				current_values = v
			end
		end

		openSet[current_index] = nil
		closedSet[current_index] = current_values
		count = count - 1

		if current_index == target_index then
			-- print("Success")
			local path = {}
			local reverse_path = {}
			repeat
				if not closedSet[current_index] then
					return
				end
				table.insert(path, closedSet[current_index].pos)
				current_index = closedSet[current_index].parent
				if #path > 100 then
					-- print("path to long")
					return
				end
			until start_index == current_index
			repeat
				table.insert(reverse_path, table.remove(path))
			until #path == 0
			-- print("path lenght: "..#reverse_path)
			return reverse_path
		end

		local current_pos = current_values.pos

		local neighbors = {}
		local neighbors_index = 1
		for z = -1, 1 do
			for x = -1, 1 do
				local neighbor_pos = {x = current_pos.x + x, y = current_pos.y, z = current_pos.z + z}
				local neighbor = minetest.get_node(neighbor_pos)
				local neighbor_ground_level = get_neighbor_ground_level(neighbor_pos, entity_jump_height, entity_fear_height)
				local neighbor_clearance = false
				if neighbor_ground_level then
					-- print(neighbor_ground_level.y - current_pos.y)
					--minetest.set_node(neighbor_ground_level, {name = "default:dry_shrub"})
					local node_above_head = minetest.get_node(
						{x = current_pos.x, y = current_pos.y + entity_height, z = current_pos.z})
					if neighbor_ground_level.y - current_pos.y > 0 and not walkable(node_above_head) then
						local height = -1
						repeat
							height = height + 1
							local node = minetest.get_node(
								{x = neighbor_ground_level.x,
									y = neighbor_ground_level.y + height,
									z = neighbor_ground_level.z})
						until walkable(node) or height > entity_height
						if height >= entity_height then
							neighbor_clearance = true
						end
					elseif neighbor_ground_level.y - current_pos.y > 0 and walkable(node_above_head) then
						neighbors[neighbors_index] = {
							hash = nil,
							pos = nil,
							clear = nil,
							walkable = nil,
						}
					else
						local height = -1
						repeat
							height = height + 1
							local node = minetest.get_node(
								{x = neighbor_ground_level.x,
									y = current_pos.y + height,
									z = neighbor_ground_level.z})
						until walkable(node) or height > entity_height
						if height >= entity_height then
							neighbor_clearance = true
						end
					end

					neighbors[neighbors_index] = {
						hash = minetest.hash_node_position(neighbor_ground_level),
						pos = neighbor_ground_level,
						clear = neighbor_clearance,
						walkable = walkable(neighbor),
					}
				else
					neighbors[neighbors_index] = {
						hash = nil,
						pos = nil,
						clear = nil,
						walkable = nil,
					}
				end
				neighbors_index = neighbors_index + 1
			end
		end

		for id, neighbor in pairs(neighbors) do
			-- don't cut corners
			local cut_corner = false
			if id == 1 then
				if not neighbors[id + 1].clear or not neighbors[id + 3].clear
						or neighbors[id + 1].walkable or neighbors[id + 3].walkable then
					cut_corner = true
				end
			elseif id == 3 then
				if not neighbors[id - 1].clear or not neighbors[id + 3].clear
						or neighbors[id - 1].walkable or neighbors[id + 3].walkable then
					cut_corner = true
				end
			elseif id == 7 then
				if not neighbors[id + 1].clear or not neighbors[id - 3].clear
						or neighbors[id + 1].walkable or neighbors[id - 3].walkable then
					cut_corner = true
				end
			elseif id == 9 then
				if not neighbors[id - 1].clear or not neighbors[id - 3].clear
						or neighbors[id - 1].walkable or neighbors[id - 3].walkable then
					cut_corner = true
				end
			end

			if neighbor.hash ~= current_index and not closedSet[neighbor.hash] and neighbor.clear and not cut_corner then
				local move_cost_to_neighbor = current_values.gCost + get_distance_to_neighbor(current_values.pos, neighbor.pos)
				local gCost = 0
				if openSet[neighbor.hash] then
					gCost = openSet[neighbor.hash].gCost
				end
				if move_cost_to_neighbor < gCost or not openSet[neighbor.hash] then
					if not openSet[neighbor.hash] then
						count = count + 1
					end
					local hCost = get_distance(neighbor.pos, endpos)
					openSet[neighbor.hash] = {
						gCost = move_cost_to_neighbor,
						hCost = hCost,
						fCost = move_cost_to_neighbor + hCost,
						parent = current_index,
						pos = neighbor.pos
					}
				end
			end
		end
		if count > 100 then
			-- print("fail")
			return
		end
	until count < 1
	-- print("count < 1")
	return {pos}
end
