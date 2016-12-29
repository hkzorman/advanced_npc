-- Actions code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- The NPCs will be able to perform five fundamental actions that will allow
-- for them to perform any other kind of interaction in the world. These
-- fundamental actions are: place a node, dig a node, put items on an inventory,
-- take items from an inventory, find a node closeby (radius 3) and
-- walk a step on specific direction. These actions will be set on an action queue. 
-- The queue will have the specific steps, in order, for the NPC to be able to do 
-- something (example, go to a specific place and put a chest there). The 
-- fundamental actions are added to the action queue to make a complete task for the NPC.

npc.actions = {}

-- Describes actions with doors or openable nodes
npc.actions.door_action = {
  OPEN = 1,
  CLOSE = 2
}

-- Describe the state of doors or openable nodes
npc.actions.door_state = {
  OPEN = 1,
  CLOSED = 2
}

function npc.actions.rotate(args)
  local self = args.self
  local dir = args.dir
  local yaw = 0
  self.rotate = 0
  if dir == npc.direction.north then
    yaw = 0
  elseif dir == npc.direction.east then
    yaw = (3 * math.pi) / 2
  elseif dir == npc.direction.south then
    yaw = math.pi
  elseif dir == npc.direction.west then
    yaw = math.pi / 2
  end
  self.object:setyaw(yaw)
end

-- This function will make the NPC walk one step on a 
-- specifc direction. One step means one node. It returns 
-- true if it can move on that direction, and false if there is an obstacle
function npc.actions.walk_step(args)
  local self = args.self
  local dir = args.dir
  local vel = {}
  if dir == npc.direction.north then
    vel = {x=0, y=0, z=0.98}
  elseif dir == npc.direction.east then
    vel = {x=0.98, y=0, z=0}
  elseif dir == npc.direction.south then
    vel = {x=0, y=0, z=-0.98}
  elseif dir == npc.direction.west then
    vel = {x=-0.98, y=0, z=0}
  end
  set_animation(self, "walk")
  npc.actions.rotate({self=self, dir=dir})
  self.object:setvelocity(vel)
end

-- This action makes the NPC stand and remain like that
function npc.actions.stand(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set stand animation
  set_animation(self, "stand")
end

-- This action makes the NPC sit on the node where it is
function npc.actions.sit(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_SIT_START,
        y = npc.ANIMATION_SIT_END},
        self.animation.speed_normal, 0)
end

-- This action makes the NPC lay on the node where it is
function npc.actions.lay(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_LAY_START,
        y = npc.ANIMATION_LAY_END},
        self.animation.speed_normal, 0)
end

-- Inventory functions for players and for nodes
-- This function is a convenience function to make it easy to put
-- and get items from another inventory (be it a player inv or 
-- a node inv)
function npc.actions.put_item_on_external_inventory(args)
  local self = args.self
  local player = args.player
  local pos = args.pos
  local inv_list = args.inv_list
  local item_name = args.item_name
  local count = args.count
  local is_furnace = args.is_furnace
  local inv
  if player ~= nil then
    inv = minetest.get_inventory({type="player", name=player})
  else
    inv = minetest.get_inventory({type="node", pos=pos})
  end

  -- Create ItemStack to put on external inventory
  local item = ItemStack(item_name.." "..count)
  -- Check if there is enough room to add the item on external invenotry
  if inv:room_for_item(inv_list, item) then
    -- Take item from NPC's inventory
    if npc.take_item_from_inventory_itemstring(self, item) then
      -- NPC doesn't have item and/or specified quantity
      return false
    end
    -- Add items to external inventory
    inv:add_item(inv_list, item)
    
    -- If this is a furnace, start furnace timer
    if is_furnace == true then
      minetest.get_node_timer(pos):start(1.0)
    end

    return true
  end
  -- Not able to put on external inventory
  return false
end

function npc.actions.take_item_from_external_inventory(args)
  local self = args.self
  local player = args.player
  local pos = args.pos
  local inv_list = args.inv_list
  local item_name = args.item_name
  local count = args.count
  local inv
  if player ~= nil then
    inv = minetest.get_inventory({type="player", name=player})
  else
    inv = minetest.get_inventory({type="node", pos})
  end
  -- Create ItemSTack to take from external inventory
  local item = ItemStack(item_name.." "..count)
  -- Check if there is enough of the item to take
  if inv:contains_item(inv_list, item) then
    -- Add item to NPC's inventory
    npc.add_item_to_inventory_itemstring(self, item)
    -- Add items to external inventory
    inv:remove_item(inv_list, item)
    return true
  end
  -- Not able to put on external inventory
  return false
end

-- This function is used to open or close doors from
-- that use the default doors mod
function npc.actions.use_door(args)
  local self = args.self
  local pos = args.pos
  local action = args.action
  local node = minetest.get_node(pos)
  local state = npc.actions.door_state.CLOSED
  local a_i1, a_i2 = string.find(node.name, "_a")
  if a_i1 == nil then
    state = npc.actions.door_state.OPEN
  end
  --minetest.log("Node: "..dump(node)..". State: "..dump(state)..", Action: "..dump(action))
  local clicker = self.object
  if action ~= state then
    minetest.registered_nodes[node.name].on_rightclick(pos, node, clicker, nil, nil)
  end
end


---------------------------------------------------------------------------------------
-- Tasks functionality
---------------------------------------------------------------------------------------
-- Tasks are operations that require many actions to perform. Basic tasks, like
-- walking from one place to another, operating a furnace, storing or taking
-- items from a chest, opening/closing doors, etc. are provided here.

-- This function allows a NPC to use a furnace using only items from
-- its own inventory. Fuel is not provided. Once the furnace is finished
-- with the fuel items the NPC will take whatever was cooked and whatever
-- remained to cook. The function received the position of the furnace
-- to use, and the item to cook in furnace. Item is an itemstring
function npc.actions.use_furnace(self, pos, item)
  -- Check if any item in the NPC inventory serve as fuel
  -- For now, just use some specific items as fuel
  local fuels = {"default:leaves", "default:tree"}
  -- Check if NPC has a fuel item
  for i = 1,2 do
    local fuel_item = npc.inventory_contains(self, fuels[i]) 
    local src_item = npc.inventory_contains(self, item)

    if fuel_item ~= nil and src_item ~= nil then
      -- Put this item on the fuel inventory list of the furnace
      local args = {
         self = self,
         player = nil, 
         pos = pos, 
         inv_list = "fuel",
         item_name = npc.get_item_name(fuel_item.item_string),
         count = npc.get_item_count(fuel_item.item_string)
      }
      minetest.log("Adding fuel action")
      npc.add_action(self, npc.actions.put_item_on_external_inventory, args)
      -- Put the item that we want to cook on the furnace
      args = {
         self = self,
         player = nil, 
         pos = pos, 
         inv_list = "src",
         item_name = npc.get_item_name(src_item.item_string),
         count = npc.get_item_count(src_item.item_string),
         is_furnace = true
      }
      minetest.log("Adding src action")
      npc.add_action(self, npc.actions.put_item_on_external_inventory, args)

      return true
    end
  end
  -- Couldn't use the furnace due to lack of items
  return false
end


function npc.actions.walk_to_pos(self, end_pos)

  local start_pos = self.object:getpos()

  -- Find path
  local path = npc.actions.find_path({x=start_pos.x, y=start_pos.y-1, z=start_pos.z}, end_pos)

  if path ~= nil then
    minetest.log("Found path to node: "..dump(end_pos))

    -- Add a first step
    local dir = npc.actions.get_direction(start_pos, path[1].pos)
    npc.add_action(self, npc.actions.walk_step, {self = self, dir = dir})

    -- Add subsequent steps
    for i = 1, #path do
      --minetest.log("Path: (i) "..dump(path[i])..": Path i+1 "..dump(path[i+1]))
      -- Do not add an extra step
      if i == #path then
        -- Add direction to last node
        local dir = npc.actions.get_direction(path[i].pos, end_pos)
        -- Add stand animation at end
        npc.add_action(self, npc.actions.stand, {self = self})
        -- Rotate to face the end node
        npc.actions.rotate({self = self, dir = dir})
        break
      end
      -- Get direction to move from path[i] to path[i+1]
      local dir = npc.actions.get_direction(path[i].pos, path[i+1].pos)
      -- Add walk action to action queue
      npc.add_action(self, npc.actions.walk_step, {self = self, dir = dir})
    end
  end
end

local function vector_opposite(v)
  return vector.multiply(v, -1)
end

local function get_unit_dir_vector_based_on_diff(v)
  if math.abs(v.x) > math.abs(v.z) then
    return {x=(v.x/math.abs(v.x)) * -1, y=0, z=0}
  elseif math.abs(v.z) > math.abs(v.x) then
    return {x=0, y=0, z=(v.z/math.abs(v.z)) * -1}
  elseif math.abs(v.x) == math.abs(v.z) then
    return {x=(v.x/math.abs(v.x)) * -1, y=0, z=0}
  end
end

-- This function returns the direction enum
-- for the moving from v1 to v2
function npc.actions.get_direction(v1, v2)
  local dir = vector.subtract(v2, v1)
  if dir.x ~= 0 then
    if dir.x > 0 then
      return npc.direction.east
    else
      return npc.direction.west
    end
  elseif dir.z ~= 0 then
    if dir.z > 0 then
      return npc.direction.north
    else
      return npc.direction.south
    end
  end
end

-- This function is used to determine if a node is walkable
-- or openable, in which case is good to use when finding a path
local function is_good_node(node)
  -- Is openable is to support doors, fence gates and other
  -- doors from other mods. Currently, default doors and gates
  -- will be supported. Cottages doors should also be supported.
  --minetest.log("Node name: "..dump(node.name))
  local is_openable = false
  local start_i,end_i = string.find(node.name, "doors:")
  is_openable = start_i ~= nil
  --minetest.log("Is node openable: "..dump(is_openable))
  --minetest.log("Is node walkable: "..dump(not minetest.registered_nodes[node.name].walkable))
  if not minetest.registered_nodes[node.name].walkable then
    return "W"
  elseif is_openable then
    return "O"
  else
    return "N"
  end
end

DIFF_LIMIT = 125

-- Finds paths ignoring vertical obstacles
-- This function is recursive and attempts to move all the time on
-- the direction that will definetely lead to the end position.
local function find_path_recursive(start_pos, end_pos, path_nodes, last_dir, last_good_dir)
  --minetest.log("Start pos: "..dump(start_pos))

  -- Find difference. The purpose of this is to weigh movement, attempting
  -- the largest difference first, or both if equal.
  local diff = vector.subtract(start_pos, end_pos)

  --minetest.log("Difference: "..dump(diff))

  -- End if difference is larger than max difference possible (limit)
  if math.abs(diff.x) > DIFF_LIMIT or math.abs(diff.z) > DIFF_LIMIT then
    -- Cannot find feasable path
    return nil
  end
  -- Determine direction to move
  local dir_vector = get_unit_dir_vector_based_on_diff(diff)

  --minetest.log("Direction vector: "..dump(dir_vector))

  if last_good_dir ~= nil then
    dir_vector = last_good_dir
  end

  -- Get next position based on direction
  local next_pos = vector.add(start_pos, dir_vector)

  --minetest.log("Next pos: "..dump(next_pos))

  -- Check if next_pos is actually within one block from the
  -- expected position. If so, finish
  local diff_to_end = vector.subtract(next_pos, end_pos)
  if math.abs(diff_to_end.x) < 1 and math.abs(diff_to_end.y) < 1 and math.abs(diff_to_end.z) < 1 then
    --minetest.log("Diff to end: "..dump(diff_to_end))
    table.insert(path_nodes, {pos=next_pos, type="E"})
    minetest.log("Found path to end.")
    return path_nodes
  end
  -- Check if movement is possible on the calculated direction
  local next_node = minetest.get_node(next_pos)
  -- If direction vector is opposite to the last dir, then do not attempt to walk into it
  --minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
  local attempted_to_go_opposite = false
  if last_dir ~= nil and vector.equals(dir_vector, vector_opposite(last_dir)) then
    attempted_to_go_opposite = true
    --minetest.log("Last dir: "..dump(last_dir))
    --minetest.log("Calculated dir vector is the opposite of last dir: "..dump(vector.equals(dir_vector, vector_opposite(last_dir))))
  end

  local node_type = is_good_node(next_node)
  if node_type ~= "N" and (not attempted_to_go_opposite) then
    table.insert(path_nodes, {pos=next_pos, type=node_type})
    return find_path_recursive(next_pos, end_pos, path_nodes, nil, nil)
  else
    --minetest.log("------------ Second attempt ------------")
    
    -- If not walkable, attempt turn into the other coordinate
    -- Determine this coordinate based on what was the last calculated direction
    -- that didn't needed correction (last good dir). If this doesn't exists (e.g.
    -- there has been no correction for a while) then select the direction by
    -- trying to shorten the distance between NPC and the end node.

    --minetest.log("Last known good dir: "..dump(last_good_dir))
    local step = 0
    if last_good_dir == nil then
      -- Store the current direction vector as the last non-corrected
      -- calculated direction
      last_good_dir = dir_vector

      -- Determine which direction to move 
      if dir_vector.x == 0 then
        --minetest.log("Choosing x direction")
        step = diff.x/math.abs(diff.x) * -1
        if diff.x == 0 then
          if last_dir ~= nil then
            step = last_dir.x
          else
            -- Set a default step to avoid locks
            step = 1
          end
        end
        dir_vector = {x = step, y = 0, z = 0}
      elseif dir_vector.z == 0 then
        step = diff.z/math.abs(diff.z) * -1
        if diff.z == 0 then
          if last_dir ~= nil then
            step = last_dir.z
          else
            -- Set a default step to avoid locks
            step = 1
          end
        end
        dir_vector = {x = 0, y = 0, z = step}
      end
      --minetest.log("Re-calculated dir vector: "..dump(dir_vector))
      next_pos = vector.add(start_pos, dir_vector)
    else
      dir_vector = last_good_dir
      if dir_vector.x == 0 then
        --minetest.log("Moving into x direction")
        step = last_dir.x
      elseif dir_vector.z == 0 then
        --minetest.log("Moving into z direction")
        step = last_dir.z
      end
      dir_vector = last_dir
      next_pos = vector.add(start_pos, dir_vector)
    end

    -- Check if new node is walkable
    next_node = minetest.get_node(next_pos)

    --minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))

    local node_type = is_good_node(next_node)
    if node_type ~= "N" then
      table.insert(path_nodes, {pos=next_pos, type=node_type})
      return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir)
    else
      last_good_dir = dir_vector
      --minetest.log("------------ Third attempt ------------")

      -- If not walkable, then try the next node
      if dir_vector.x ~= 0 then
        --minetest.log("Move into opposite z dir")
        dir_vector = get_unit_dir_vector_based_on_diff(start_pos, diff)
        vector.multiply(dir_vector, -1)
      elseif dir_vector.z ~= 0 then
        --minetest.log("Move into opposite x dir")
        dir_vector = get_unit_dir_vector_based_on_diff(start_pos, diff)
        vector.multiply(dir_vector, -1)
      end
      --minetest.log("New direction: "..dump(dir_vector))

      next_pos = vector.add(start_pos, dir_vector)
      --minetest.log("New next_pos: "..dump(next_pos))
      next_node = minetest.get_node(next_pos)
      --minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
      local node_type = is_good_node(next_node)
      if node_type ~= "N" then
        table.insert(path_nodes, {pos=next_pos, type=node_type})
        return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir)
      else
        -- Try to return back, opposite of last dir. For now return nil as this code 
        -- is not good enough to work correctly.
        return nil
      end
    end
  end

end

function npc.actions.find_path(start_pos, end_pos)
  return find_path_recursive(start_pos, end_pos, {}, nil, nil)
end