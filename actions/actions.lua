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
    vel = {x=0, y=0, z=1}
  elseif dir == npc.direction.east then
    vel = {x=1, y=0, z=0}
  elseif dir == npc.direction.south then
    vel = {x=0, y=0, z=-1}
  elseif dir == npc.direction.west then
    vel = {x=-1, y=0, z=0}
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

  minetest.log("Starting pos: "..dump(start_pos))

  -- Use Minetest built-in pathfinding algorithm, A*
  local path = npc.actions.find_path({x=start_pos.x, y=start_pos.y-1, z=start_pos.z}, end_pos)

  if path ~= nil then
    minetest.log("Found path to node: "..dump(end_pos))
    for i = 1, #path do
      minetest.log("Path: (i) "..dump(path[i])..": Path i+1 "..dump(path[i+1]))
      local dir = npc.actions.get_direction(path[i].pos, path[i+1].pos)
      -- Add walk action to action queue
      npc.add_action(self, npc.actions.walk_step, {self = self, dir = dir})
      if i+1 == #path then
        break
      end
    end
  end

  -- Add stand animation at end
  npc.add_action(self, npc.actions.stand, {self = self})

end

local function vector_add(p1, p2)
  return {x=p1.x+p2.x, y=p1.y+p2.y, z=p1.z+p2.z}
end

local function vector_diff(p1, p2)
  return {x=p1.x-p2.x, y=p1.y-p2.y, z=p1.z-p2.z}
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

DIFF_LIMIT = 125

-- Finds paths ignoring vertical obstacles
-- This function is recursive and attempts to move all the time on
-- the direction that will definetely lead to the end position.
local function find_path_recursive(start_pos, end_pos, path_nodes, last_dir, last_good_dir)
  minetest.log("Start pos: "..dump(start_pos))
  -- Find difference. The purpose of this is to weigh movement, attempting
  -- the largest difference first, or both if equal.

  local diff = vector_diff(start_pos, end_pos)
  minetest.log("Difference: "..dump(diff))
  -- End if difference is larger than max difference possible (limit)
  if math.abs(diff.x) > DIFF_LIMIT or math.abs(diff.z) > DIFF_LIMIT then
    -- Cannot find feasable path
    return nil
  end
  -- Determine direction to move
  local dir_vector = get_unit_dir_vector_based_on_diff(diff)
  minetest.log("Direction vector: "..dump(dir_vector))

  if last_good_dir ~= nil then
    dir_vector = last_good_dir
  end

  -- Get next position based on direction
  local next_pos = vector_add(start_pos, dir_vector)

  minetest.log("Next pos: "..dump(next_pos))
  -- Check if next_pos is actually within one block from the
  -- expected position. If so, finish
  local diff_to_end = vector_diff(next_pos, end_pos)
  if math.abs(diff_to_end.x) < 1 and math.abs(diff_to_end.y) < 1 and math.abs(diff_to_end.z) < 1 then
    minetest.log("Diff to end: "..dump(diff_to_end))
    table.insert(path_nodes, {pos=next_pos, type="E"})
    minetest.log("Found path to end.")
    return path_nodes
  end
  -- Check if movement is possible on the calculated direction
  local next_node = minetest.get_node(next_pos)
  -- If direction vector is opposite to the last dir, then do not attempt to walk into it
  minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
  local attempted_to_go_opposite = false
  if last_dir ~= nil and vector.equals(dir_vector, vector_opposite(last_dir)) then
    attempted_to_go_opposite = true
    minetest.log("Last dir: "..dump(last_dir))
    minetest.log("Calculated dir vector is the opposite of last dir: "..dump(vector.equals(dir_vector, vector_opposite(last_dir))))
  end
  if minetest.registered_nodes[next_node.name].walkable == false
    and (not attempted_to_go_opposite) then
    table.insert(path_nodes, {pos=next_pos, type="W"})
    return find_path_recursive(next_pos, end_pos, path_nodes, nil, nil)
  else
    minetest.log("------------ Second attempt ------------")
    -- If not walkable, attempt turn into the other coordinate
    -- Store last good direction to retry at all times
    minetest.log("Last known good dir: "..dump(last_good_dir))
    local step = 0
    if last_good_dir == nil then
      last_good_dir = dir_vector
      if dir_vector.x == 0 then
        minetest.log("Choosing x direction")
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
        minetest.log("Choosing z direction")
        step = diff.z/math.abs(diff.z) * -1
        minetest.log("Step: "..dump(step)..". Diff: "..dump(diff))
        minetest.log("Last dir: ".. dump(last_dir))
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
      minetest.log("Re-calculated dir vector: "..dump(dir_vector))
      next_pos = vector.add(start_pos, dir_vector)
    else
      dir_vector = last_good_dir
      if dir_vector.x == 0 then
        minetest.log("Moving into x direction")
        step = last_dir.x
      elseif dir_vector.z == 0 then
        minetest.log("Moving into z direction")
        step = last_dir.z
      end
      dir_vector = last_dir
      next_pos = vector.add(start_pos, dir_vector)
    end

    

    -- if dir_vector.x == 0 then
    --   minetest.log("Moving into x direction")
    --   local step = diff.x/math.abs(diff.x) * -1
    --   if diff.x == 0 then
    --     -- If the difference for x with end position is zero, then try
    --     -- to move in the last known direction
    --     if last_dir ~= nil then
    --       step = last_dir.x
    --     end
    --   end
    --   next_pos = {x = start_pos.x + step, y = start_pos.y, z = start_pos.z}
    --   dir_vector = {x = step, y = 0, z = 0}
    -- elseif dir_vector.z == 0 then
    --   minetest.log("Moving into z direction")
    --   local step = diff.z/math.abs(diff.z) * -1
    --   if diff.z == 0 then
    --     -- If the difference for z with end position is zero, then try
    --     -- to move in the last known direction
    --     if last_dir ~= nil then
    --       step = last_dir.z
    --     end
    --   end
    --   next_pos = {x = start_pos.x, y = start_pos.y, z = start_pos.z + step}
    --   dir_vector = {x = 0, y = 0, z = step}
    -- end
    minetest.log("Next calculated position: "..dump(next_pos))

    -- Check if new node is walkable
    next_node = minetest.get_node(next_pos)
    minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
    if last_dir ~= nil and vector.equals(dir_vector, vector_opposite(last_dir)) then
      attempted_to_go_opposite = true
      minetest.log("Last dir: "..dump(last_dir))
      minetest.log("Calculated dir vector is the opposite of last dir: "..dump(vector.equals(dir_vector, vector_opposite(last_dir))))
    end
    if minetest.registered_nodes[next_node.name].walkable == false then
      table.insert(path_nodes, {pos=next_pos, type="W"})
      return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir)
    else
      last_good_dir = dir_vector
      minetest.log("------------ Third attempt ------------")
      -- If not walkable, then try the next node
      if dir_vector.x ~= 0 then
        minetest.log("Move into opposite z dir")
        dir_vector = get_unit_dir_vector_based_on_diff(start_pos, diff)
        vector.multiply(dir_vector, -1)
      elseif dir_vector.z ~= 0 then
        minetest.log("Move into opposite x dir")
        dir_vector = get_unit_dir_vector_based_on_diff(start_pos, diff)
        vector.multiply(dir_vector, -1)
      end
      minetest.log("New direction: "..dump(dir_vector))

      next_pos = vector_add(start_pos, dir_vector)
      minetest.log("New next_pos: "..dump(next_pos))
      next_node = minetest.get_node(next_pos)
      minetest.log("Next node is walkable: "..dump(not minetest.registered_nodes[next_node.name].walkable))
      -- if last_dir ~= nil and vector.equals(dir_vector, vector_opposite(last_dir)) then
      --   attempted_to_go_opposite = true
      --   minetest.log("Last dir: "..dump(last_dir))
      --   minetest.log("Calculated dir vector is the opposite of last dir: "..dump(vector.equals(dir_vector, vector_opposite(last_dir))))
      -- end
      if minetest.registered_nodes[next_node.name].walkable == false then
        --and (not attempted_to_go_opposite) then
        table.insert(path_nodes, {pos=next_pos, type="W"})
        return find_path_recursive(next_pos, end_pos, path_nodes, dir_vector, last_good_dir)
      else
        --return back, opposite of last dir. For now return nil as this code is not
        -- good
        return nil
        -- minetest.log("Have to go back")
        -- local return_dir = vector_opposite(last_dir)
        -- -- If it is returning back already, continue on that direction
        -- if attempted_to_go_opposite then
        --   return_dir = last_dir
        -- end
        -- minetest.log("Opposite dir: "..dump(return_dir))
        -- next_pos = vector_add(start_pos, return_dir)
        -- minetest.log("Calculated pos: "..dump(next_pos))
        -- return find_path(next_pos, end_pos, return_dir)
      end
    end
  end

end

function npc.actions.find_path(start_pos, end_pos)
  return find_path_recursive(start_pos, end_pos, {}, nil, nil)
end