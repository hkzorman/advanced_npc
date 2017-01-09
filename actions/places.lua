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
	 "cottages:bench"
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
function npc.places.find_node_nearby(self, type, radius)
  -- Get current pos
  local current_pos = self.object:getpos()
   -- Determine area points
  local start_pos = {x=current_pos.x - radius, y=current_pos.y - 1, z=current_pos.z - radius}
  local end_pos = {x=current_pos.x + radius, y=current_pos.y + 1, z=current_pos.z + radius}
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