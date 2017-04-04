-- Pathfinder by Zorman2000
-- Pathfinding code with included A* implementation, customized
-- for Minetest. At the moment, paths can only be found in flat
-- terrain (only 2D pathfinding)

-- Public namespace
pathfinder = {}
-- Private namespace for pathfinder functions
local finder = {}

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

function pathfinder.find_path(start_pos, end_pos, extra_range, walkable_nodes)
  -- Create map
  local map = finder.create_map(start_pos, end_pos, extra_range, walkable_nodes)
  minetest.log("Number of nodes in map: "..dump(#map))
  -- Use A* algorithm
  local path = minetest.find_path(start_pos, end_pos, 30, 1, 1, "Dijkstra")
  minetest.log("Path: "..dump(path))
  return path
  --return finder.astar({name="air", pos=start_pos}, {name="air", pos=end_pos}, map)
end

-- This function is used to determine if a node is walkable
-- or openable, in which case is good to use when finding a path
function finder.is_good_node(node, exceptions)
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

-- Maps a 2D slice of Minetest terrain into an array of nodes
-- Extra range is a number that will be added in the x and the z coordinates
-- to allow more room to find paths.
-- Walkables is an array of node names which are considered walkable,
-- even if they are not.
function finder.create_map(start_pos, end_pos, extra_range, walkables)

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

  minetest.log("Recalculated pos1: "..minetest.pos_to_string(pos1))
  minetest.log("Recalculated pos2: "..minetest.pos_to_string(pos2))

  local grid = {}

  -- Loop through the area and classify nodes
  for z = 1, math.abs(pos1.z - pos2.z) do
    --local current_row = {}
    for x = 1, math.abs(pos1.x - pos2.x) do
      -- Calculate current position
      local current_pos = {x=pos1.x + (x*end_x_sign), y=pos1.y, z=pos1.z + (z*end_z_sign)}
       -- Get node info
      local node = minetest.get_node(current_pos)
      -- Check if this is the starting position
      if current_pos.x == start_pos.x and current_pos.z == start_pos.z then
        -- Is start position
        table.insert(grid, {name=node.name, pos=current_pos, type=pathfinder.node_types.start})
      elseif current_pos.x == end_pos.x and current_pos.z == end_pos.z then
        -- Is ending position or goal position
        table.insert(grid, {name=node.name, pos=current_pos, type=pathfinder.node_types.goal})
      else
        -- Check if node is walkable
        if node.name == "air" then
          -- If air do no more checks
          table.insert(grid, {name=node.name, pos=current_pos, type=pathfinder.node_types.walkable})
        else
          -- Check if it is of a walkable or openable type
          table.insert(grid, {name=node.name, pos=current_pos, type=finder.is_good_node(node, walkables)})
        end
      end
    end
    -- Insert the converted row into the grid
    --table.insert(grid, current_row)
  end

  return grid
end

--------------------------------------------------------------------------
-- A* algorithm implementation
--------------------------------------------------------------------------
-- Utility functions
function finder.distance(node1, node2)
  return math.sqrt(math.pow(node2.pos.x - node1.pos.x, 2) + math.pow(node2.pos.z - node1.pos.z, 2))
end

function finder.is_valid_neighbor(node1, node2)
  -- Consider only orthogonal nodes
  if (node1.pos.x == node2.pos.x and node1.pos.z ~= node2.pos.z) 
    or (node1.pos.z == node2.pos.z and node1.pos.x ~= node2.pos.z) then
    if (finder.distance(node1, node2) < 2) then
      return finder.is_good_node(node2, {})
    end
  end
  return false
end 

function finder.cost_estimate(node1, node2)
  return finder.distance(node1, node2)
end

function finder.get_lowest_fscore(nodes, f_scores)
  local lowest = 1/0
  local best_node = nil
  for _, node in pairs(nodes) do
    local score = f_scores[node]
    if score < lowest then
      lowest = score
      best_node = node
    end
  end
  return best_node
end

function finder.get_neighbor(node, nodes)
  local neighbors = {}
  for _, current_node in pairs(nodes) do
    if current_node ~= node then
      if finder.is_valid_neighbor(node, current_node) then
        table.insert(neighbors, current_node)
      end
    end
  end
  return neighbors
end

function finder.contains_node(node, all_nodes)
  for _,current_node in pairs(all_nodes) do
    if current_node == node then
      return true
    end
  end
  return false
end

function finder.remove_node(node, all_nodes)
  --minetest.log("On remove_node: "..dump(all_nodes))
  for key, current_node in pairs(all_nodes) do
    if current_node == node then
      --minetest.log("Table before: "..dump(all_nodes))
      table.remove(all_nodes, key)
      --minetest.log("Table after: "..dump(all_nodes))
      return
    end
  end
end

function finder.create_path(path, grid, node)
  if grid[node] ~= nil then
    table.insert(path, 1, grid[node])
    return create_path(path, grid, grid[node])
  else
    return path
  end
end

function finder.astar(start_pos, end_pos, nodes)

  local closed_set = {}
  local open_set = {
    start_pos
  }
  local came_from = {}

  local g_score = {}
  local f_score = {}
  g_score[start_pos] = 0
  f_score[start_pos] = g_score[start_pos] + finder.cost_estimate(start_pos, end_pos)

  minetest.log("Open set: "..dump(#open_set))

  while #open_set > 0 do
    minetest.log("Nodes size: "..dump(#nodes))

    local current = finder.get_lowest_fscore(open_set, f_score)
    minetest.log("Node with best fscore: "..dump(current))
    if current == end_pos then
      minetest.log("Creating path: "..dump(came_from))
      local path = create_path({}, came_from, end_pos)
      table.insert(path, end_pos)
      return path
    end

    minetest.log("Removing node from openset..."..dump(#open_set))
    finder.remove_node(current, open_set)    
    minetest.log("Removed. Open set size: "..dump(#open_set))
    minetest.log("Adding to closed set..."..dump(#closed_set))
    table.insert(closed_set, current)
    minetest.log("Added. New closed set size: "..dump(#closed_set))
    
    local neighbors = finder.get_neighbor(current, nodes)
    minetest.log("Found "..dump(#neighbors).." neighbors for current node")--dump(neighbors))
    for _, neighbor in pairs(neighbors) do 
      minetest.log("Currently looking at neighbor: "..minetest.pos_to_string(neighbor.pos))
      if finder.contains_node(neighbor, closed_set) == false then
        minetest.log("Node is not in closed set")
      
        local tentative_g_score = g_score[current] + finder.distance(current, neighbor)
        minetest.log("Tentative g score is: "..dump(tentative_g_score))
        minetest.log("Logic: "..dump(finder.contains_node(neighbor, open_set) == false or tentative_g_score < g_score[neighbor]))
        if finder.contains_node(neighbor, open_set) == false or tentative_g_score < g_score[neighbor] then 
          came_from[neighbor] = current
          minetest.log("Added node to came_from set: "..dump(table.getn(came_from)))
          g_score[neighbor] = tentative_g_score
          f_score[neighbor] = g_score[neighbor] + finder.cost_estimate(neighbor, end_pos)
          if finder.contains_node(neighbor, open_set) == false then
            minetest.log("Adding neighbor node to open_set: "..dump(#open_set))
            table.insert(open_set, neighbor)
            minetest.log("Added. New open set size: "..dump(#open_set))
          end
        end
      end
    end
  end
  -- Path not found
  return nil
end
