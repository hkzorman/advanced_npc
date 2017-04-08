-- Pathfinding code by Zorman2000
---------------------------------------------------------------------------------------
-- Pathfinding functionality
---------------------------------------------------------------------------------------
-- This class contains functions that allows to map the 3D map of Minetest into 
-- a 2D array (basically by ignoring the y coordinate for the moment being) in order
-- to use the A* pathfinding algorithm to find the shortest path from one node to
-- another. The A* algorithm implementation is in the 'jumper.lua' file which a 
-- reduced and slightly modified version of the Jumper library, by Roland Yonaba 
-- (https://github.com/Yonaba/Jumper).
-- Mapping algorithm: transforms a Minetest map surface to a 2d grid.

pathfinder = {}

pathfinder.node_types = {
  start = 0,
  goal = 1,
  walkable = 2,
  openable = 3,
  non_walkable = 4
}

pathfinder.nodes = {
  openable_prefix = {
    "doors:",
    "cottages:gate",
    "cottages:half_door"
  }
} 


-- This function uses the mapping functions and the A* algorithm implementation
-- of the Jumper library to find a path from start_pos to end_pos. The range is
-- an extra amount of nodes to search in both the x and z coordinates.
function pathfinder.find_path(start_pos, end_pos, range, walkable_nodes)
  -- Check that start and end position are not the same
  if start_pos.x == end_pos.x and start_pos.z == end_pos.z then
    return nil
  end
  -- Set walkable nodes to empty if parameter wasn't used
  if walkable_nodes == nil then
    walkable_nodes = {}
  end
  -- Map the Minetest area to a 2D array
  local map = pathfinder.create_map(start_pos, end_pos, range, walkable_nodes)
  -- Find start and end positions
  local pos = pathfinder.find_start_and_end_pos(map)
  -- Normalize the map
  local normalized_map = pathfinder.normalize_map(map)
  -- Create pathfinder object
  local grid_object = Grid(normalized_map)
  -- Define what is a walkable node
  local walkable = 0

  -- Pathfinder object using A* algorithm
  local finder = Pathfinder(grid_object, "ASTAR", walkable)
  -- Set orthogonal mode meaning it will not move in diagonal directions
  finder:setMode("ORTHOGONAL")

  -- Calculates the path, and its length
  local path = finder:getPath(pos.start_pos.x, pos.start_pos.z, pos.end_pos.x, pos.end_pos.z)

  --minetest.log("Found path: "..dump(path))
  -- Pretty-printing the results
  if path then
    return pathfinder.get_path(map, path:nodes())
  end
end

-- This function is used to determine if a node is walkable
-- or openable, in which case is good to use when finding a path
local function is_good_node(node, exceptions)
  -- Is openable is to support doors, fence gates and other
  -- doors from other mods. Currently, default doors, gates
  -- and cottages doors are supported.
  local is_openable = false
  for _,node_prefix in pairs(pathfinder.nodes.openable_prefix) do
    local start_i,end_i = string.find(node.name, node_prefix)
    if start_i ~= nil then
      is_openable = true
      break
    end
  end
  if node ~= nil and node.name ~= nil and not minetest.registered_nodes[node.name].walkable then
    return pathfinder.node_types.walkable
  elseif is_openable then
    return pathfinder.node_types.openable
  else
    for i = 1, #exceptions do
      if node.name == exceptions[i] then
        return pathfinder.node_types.walkable
      end
    end
    return pathfinder.node_types.non_walkable
  end
end

function pathfinder.create_map(start_pos, end_pos, extra_range, walkables)

  minetest.log("Start pos: "..minetest.pos_to_string(start_pos))
  minetest.log("End pos: "..minetest.pos_to_string(end_pos))

  -- Calculate all signs to ensure:
  -- 1. Correct area calculation
  -- 2. Iterate in the correct direction
  local start_x_sign = (start_pos.x - end_pos.x) / math.abs(start_pos.x - end_pos.x)
  local start_z_sign = (start_pos.z - end_pos.z) / math.abs(start_pos.z - end_pos.z) 
  local end_x_sign = (end_pos.x - start_pos.x) / math.abs(end_pos.x - start_pos.x)
  local end_z_sign = (end_pos.z - start_pos.z) / math.abs(end_pos.z - start_pos.z)

  -- Correct the signs if they are nan
  if math.abs(start_pos.x - end_pos.x) == 0 then
    start_x_sign = -1
    end_x_sign = 1
  end
  if math.abs(start_pos.z - end_pos.z) == 0 then
    start_z_sign = -1
    end_z_sign = 1
  end

  -- Get starting and ending positions, adding the extra nodes to the area
	local pos1 = {x=start_pos.x + (extra_range * start_x_sign), y = start_pos.y - 1, z=start_pos.z + (extra_range * start_z_sign)}
	local pos2 = {x=end_pos.x + (extra_range * end_x_sign), y = end_pos.y, z=end_pos.z + (extra_range * end_z_sign)}

	local grid = {}

  -- Loop through the area and classify nodes
	for z = 1, math.abs(pos1.z - pos2.z) do
		local current_row = {}
		for x = 1, math.abs(pos1.x - pos2.x) do
      -- Calculate current position
      local current_pos = {x=pos1.x + (x*end_x_sign), y=pos1.y, z=pos1.z + (z*end_z_sign)}
      -- Check if this is the starting position
      if current_pos.x == start_pos.x and current_pos.z == start_pos.z then
        -- Is start position
        table.insert(current_row, {pos=current_pos, type=pathfinder.node_types.start})
      elseif current_pos.x == end_pos.x and current_pos.z == end_pos.z then
        -- Is ending position or goal position
        table.insert(current_row, {pos=current_pos, type=pathfinder.node_types.goal})
      else
        -- Check if node is walkable
        local node = minetest.get_node(current_pos)
        if node.name == "air" then
          -- If air do no more checks
          table.insert(current_row, {pos=current_pos, type=pathfinder.node_types.walkable})
        else
          -- Check if it is of a walkable or openable type
          table.insert(current_row, {pos=current_pos, type=is_good_node(node, walkables)})
        end
      end
    end
    -- Insert the converted row into the grid
    table.insert(grid, current_row)
	end

  return grid
end

-- Utility function to print the created map to the console.
-- Used for debug.
local function print_map(map)
  for z,row in pairs(map) do
    local row_string = "["
    for x,node in pairs(row) do
      if node.type == 2 then
        row_string = row_string.."- "
      else
        row_string = row_string..node.type.." "
      end
      -- Use the following if the coordinates are also needed
      --row_string = row_string..node.type..": {"..node.pos.x..", "..node.pos.y..", "..node.pos.z.."}, "
    end
    row_string = row_string.."]"
    print(row_string)
  end
end


-- This function find the starting and ending points in the
-- map representation, and returns the coordinates in the map
-- for the pathfinding algorithm to use
function pathfinder.find_start_and_end_pos(map)
  -- This is for debug
  print_map(map)
  local result = {}
  for z,row in pairs(map) do
    for x,node in pairs(row) do
      if node.type == pathfinder.node_types.start then
        --minetest.log("Start node: "..dump(node))
        result["start_pos"] = {x=x, z=z} 
      elseif node.type == pathfinder.node_types.goal then
        --minetest.log("End node: "..dump(node))
        result["end_pos"] = {x=x, z=z} 
      end
    end
  end
  --minetest.log("Found start and end positions: ("..result.start_pos.)..", "..minetest.pos_to_string(result.end_pos))
  return result
end

-- This function transforms the grid into binary values 
-- (0 walkable, 1 non-walkable) for the pathfinding algorithm.
function pathfinder.normalize_map(map)
  local result = {}
  for _,row in pairs(map) do
    local result_row = {}
    for _,node in pairs(row) do
      if node.type ~= pathfinder.node_types.non_walkable then
        table.insert(result_row, 0)
      else
        table.insert(result_row, 1)
      end
    end
    table.insert(result, result_row)
  end
  return result
end

-- This function returns an array of tables with two parameters: type and pos.
-- The position parameter is the actual coordinate on the Minetest map. The
-- type is the type of the node at the coordinate defined as pathfinder.node_types.
function pathfinder.get_path(map, path_nodes)
  local result = {}
  for node, count in path_nodes do
    table.insert(result, map[node:getY()][node:getX()])
    -- For debug
    --minetest.log("Node: "..dump(map[node:getY()][node:getX()]))
    --print(('Step: %d - x: %d - y: %d'):format(count, node:getX(), node:getY()))
  end
  return result
end
