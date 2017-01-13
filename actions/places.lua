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
-- support for default and cottages is going to be provided.

npc.places = {}

npc.places.nodes = {
  BEDS = {
	 "beds:bed_bottom",
	 "beds:fancy_bed_bottom"
  }, 
  SITTABLE = {
	 "cottages:bench",
   -- TODO: Register all stairs node that are supported for sitting
   -- Hint: wood
   "stairs:stair_wood"
  },
  CHESTS = {
	 "default:chest",
	 "default:chest_locked"
  }
}

npc.places.PLACE_TYPE = {
	"OWN_BED",
	"OWN_CHEST",
	"HOUSE_CHAIR",
	"HOUSE_TABLE",
	"HOUSE_FURNACE",
	"HOUSE_ENTRANCE"
}


function npc.places.add_public(self, place_name, place_type, pos)
	self.places_map[place_name] = {type=place_type, pos=pos}
end

-- Adds a specific node to the NPC places, and modifies the
-- node metadata to identify the NPC as the owner. This allows
-- other NPCs to avoid to take this as their own.
function npc.places.add_owned(self, place_name, place_type, pos)
  -- Get node metadata
  local meta = minetest.get_meta(pos)
  -- Check if it is owned by an NPC?
  if meta:get_string("npc_owner") == "" then
    -- Set owned by NPC
    meta:set_string("npc_owner", self.npc_id)
    -- Add place to list
    npc.places.add_public(self, place_name, place_type, pos)
    return true
  end
  return false
end

function npc.places.get_by_type(self, place_type)
	local result = {}
	for place_name, place_entry in pairs(self.places_map) do
		if place_entry.type == place_type then
      table.insert(result, place_name)
    end
	end
  return result
end

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
    minetest.log("Found node: "..dump(node)..", at pos: "..dump(point))
    for _,node_name in pairs(nodes) do
      if node.name == node_name then
        table.insert(result, {name=node.name, pos=point, param2=node.param2})
      end
    end
  end
  return result
end

function npc.places.find_node_in_area(start_pos, end_pos, type)
  local nodes = minetest.find_nodes_in_area(start_pos, end_pos, type)
  return nodes
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
      local i1, i2 = string.find(node.name, "stairs:")
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
  local p1, p2 = string.find(node.name, "stairs:")
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
    minetest.log("Next node: "..dump(upper_pos))
    -- Check if next node is also a stairs node
    local up_p1, up_p2 = string.find(upper_node.name, "stairs:")
    local lo_p1, lo_p2 = string.find(lower_node.name, "stairs:")

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