-- Actions code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- The NPCs will be able to perform six fundamental actions that will allow
-- for them to perform any other kind of interaction in the world. These
-- fundamental actions are: place a node, dig a node, put items on an inventory,
-- take items from an inventory, find a node closeby (radius 3) and
-- walk a step on specific direction. These actions will be set on an action queue. 
-- The queue will have the specific steps, in order, for the NPC to be able to do 
-- something (example, go to a specific place and put a chest there). The 
-- fundamental actions are added to the action queue to make a complete task for the NPC.

npc.actions = {}

npc.actions.default_interval = 1

-- Describes actions with doors or openable nodes
npc.actions.const = {
	doors = {
		action = {
			OPEN = 1,
			CLOSE = 2
		},
		state = {
			OPEN = 1,
			CLOSED = 2
		}
	},
	beds = {
		LAY = 1,
		GET_UP = 2
	},
	sittable = {
		SIT = 1,
		GET_UP = 2
	}
}

npc.actions.cmd = {
	SET_INTERVAL = 0,
	FREEZE = 1,
	ROTATE = 2,
	WALK_STEP = 3,
	STAND = 4,
	SIT = 5,
	LAY = 6,
	PUT_ITEM = 7,
	TAKE_ITEM = 8,
	CHECK_ITEM = 9,
	USE_OPENABLE = 10,
	USE_FURNACE = 11,
	USE_BED = 12,
	USE_SITTABLE = 13,
	WALK_TO_POS = 14,
	DIG = 15,
	PLACE = 16
}

--npc.actions.one_nps_speed = 0.98
--npc.actions.one_half_nps_speed = 1.40
--npc.actions.two_nps_speed = 1.90'
npc.actions.one_nps_speed = 1
npc.actions.one_half_nps_speed = 1.5
npc.actions.two_nps_speed = 2

npc.actions.take_from_inventory = "take_from_inventory"
npc.actions.take_from_inventory_forced = "take_from_inventory_forced"
npc.actions.force_place = "force_place"

-- Executor --
--------------
-- Function references aren't reliable in Minetest entities. Objects get serialized
-- and deserialized, as well as loaded and unloaded frequently which causes many
-- function references to be lost and then crashes occurs due to nil variables.
-- Using constants to refer to each method of this API and a function that
-- understands those constants and executes the proper function is the way to avoid
-- this frequent crashes.
function npc.actions.execute(self, command, args)
	if command == npc.actions.cmd.SET_INTERVAL then
		--
		return npc.actions.set_interval(self, args)
	elseif command == npc.actions.cmd.FREEZE then
		--
		return npc.actions.freeze(self, args)
	elseif command == npc.actions.cmd.ROTATE then
		--
		return npc.actions.rotate(self, args)
	elseif command == npc.actions.cmd.WALK_STEP then
		--
		return npc.actions.walk_step(self, args)
	elseif command == npc.actions.cmd.STAND then
		--
		return npc.actions.stand(self, args)
	elseif command == npc.actions.cmd.SIT then
		--
		return npc.actions.sit(self, args)
	elseif command == npc.actions.cmd.LAY then
		--
		return npc.actions.lay(self, args)
	elseif command == npc.actions.cmd.PUT_ITEM then
		-- 
		return npc.actions.put_item_on_external_inventory(self, args)
	elseif command == npc.actions.cmd.TAKE_ITEM then
		--
		return npc.actions.take_item_from_external_inventory(self, args)
	elseif command == npc.actions.cmd.CHECK_ITEM then
		--
		return npc.actions.check_external_inventory_contains_item(self, args)
	elseif command == npc.actions.cmd.USE_OPENABLE then
		--
		return npc.actions.use_openable(self, args)
	elseif command == npc.actions.cmd.USE_FURNACE then
		--
		return npc.actions.use_furnace(self, args)
	elseif command == npc.actions.cmd.USE_BED then
		--
		return npc.actions.use_bed(self, args)
	elseif command == npc.actions.cmd.USE_SITTABLE then
		-- Call use sittable task
		return npc.actions.use_sittable(self, args)
	elseif command == npc.actions.cmd.WALK_TO_POS then
		-- Call walk to position task
		--minetest.log("Self: "..dump(self)..", Command: "..dump(command)..", args: "..dump(args))
		return npc.actions.walk_to_pos(self, args)
	elseif command == npc.actions.cmd.DIG then
		-- Call dig node action
		return npc.actions.dig(self, args)
	elseif command == npc.actions.cmd.PLACE then
		-- Call place node action
		return npc.actions.place(self, args)
	end
end

-- TODO: Thanks to executor function, all the functions for Actions and Tasks
-- should be made into private API

---------------------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------------------
-- The following action alters the timer interval for executing actions, therefore
-- making waits and pauses possible, or increase timing when some actions want to
-- be performed faster, like walking.
function npc.actions.set_interval(self, args)
	local self_actions = args.self_actions
	local new_interval = args.interval
	local freeze_mobs_api = args.freeze

	self.actions.action_interval = new_interval
	return not freeze_mobs_api
end

-- The following action is for allowing the rest of mobs redo API to be executed
-- after this action ends. This is useful for times when no action is needed
-- and the NPC is allowed to roam freely.
function npc.actions.freeze(self, args)
	local freeze_mobs_api = args.freeze
	--minetest.log("Received: "..dump(freeze_mobs_api))
	--minetest.log("Returning: "..dump(not(freeze_mobs_api)))
	return not(freeze_mobs_api)
end

-- This action digs the node at the given position
-- If 'add_to_inventory' is true, it will put the digged node in the NPC
-- inventory.
-- Returns true if dig is successful, otherwise false
function npc.actions.dig(self, args) 
	local pos = args.pos
	local add_to_inventory = args.add_to_inventory
	local bypass_protection = args.bypass_protection
	local node = minetest.get_node_or_nil(pos)
	if node then
		-- Check if protection not enforced
		if not force_dig then
			-- Try to dig node
			if minetest.dig_node(pos) then
				-- Add to inventory the node drops
				if add_to_inventory then
					-- Get node drop
					local drop = minetest.registered_nodes[node.name].drop
					-- Add to NPC inventory
					npc.npc.add_item_to_inventory(self, drop, 1)
				end
				return true
			end
		else
			-- Add to inventory
			if add_to_inventory then
				-- Get node drop
				local drop = minetest.registered_nodes[node.name].drop
				-- Add to NPC inventory
				npc.npc.add_item_to_inventory(self, drop, 1)
			end
			-- Dig node
			minetest.set_node(pos, {name="air"})
		end
	end
	return false
end


-- This action places a given node at the given position
-- There are three ways to source the node:
--   1. take_from_inventory: takes node from inventory. If not in inventory,
--		node isn't placed.
--	 2. take_from_inventory_forced: takes node from inventory. If not in
--		inventory, node will be placed anyways.
--   3. force_place: places node regardless of inventory - will not touch
--		the NPCs inventory
function npc.actions.place(self, args)
	local pos = args.pos
	local node = args.node
	local source = args.source
	local bypass_protection = args.bypass_protection
	local node_at_pos = minetest.get_node_or_nil(pos)
	-- Check if position is empty or has a node that can be built to
	if node_at_pos and 
		(node_at_pos.name == "air" or minetest.registered_nodes(node_at_pos.name).buildable_to == true) then
		-- Check protection
		if (not bypass_protection and not minetest.is_protected(pos, self.npc_name))
			or bypass_protection == true then
			-- Take from inventory if necessary
			local place_item = false
			if source == npc.actions.take_from_inventory then
				if npc.take_item_from_inventory(self, node.name, 1) then
					place_item = true
				end
			elseif source == npc.actions.take_from_inventory_forced then
				npc.take_item_from_inventory(self, node.name, 1)
				place_item = true
			elseif source == npc.actions.force_place then
				place_item = true
			end
			-- Place node
			if place_item then
				minetest.set_node(pos, node)
			end
		end
	end
end

-- This action is to rotate to mob to a specifc direction. Currently, the code
-- contains also for diagonals, but remaining in the orthogonal domain is preferrable.
function npc.actions.rotate(self, args)
	local dir = args.dir
	local yaw = 0
	self.rotate = 0
	if dir == npc.direction.north then
		yaw = 0
	elseif dir == npc.direction.north_east then
		yaw = (7 * math.pi) / 4
	elseif dir == npc.direction.east then
		yaw = (3 * math.pi) / 2
	elseif dir == npc.direction.south_east then
		yaw = (5 * math.pi) / 4
	elseif dir == npc.direction.south then
		yaw = math.pi
	elseif dir == npc.direction.south_west then
		yaw = (3 * math.pi) / 4
	elseif dir == npc.direction.west then
		yaw = math.pi / 2
	elseif dir == npc.direction.north_west then
		yaw = math.pi / 4
	end
	self.object:setyaw(yaw)
end

-- This function will make the NPC walk one step on a 
-- specifc direction. One step means one node. It returns 
-- true if it can move on that direction, and false if there is an obstacle
function npc.actions.walk_step(self, args)
	local dir = args.dir
	local speed = args.speed
	local target_pos = args.target_pos
	local vel = {}
	-- Set default node per seconds
	if speed == nil then
		speed = npc.actions.one_nps_speed
	end
	-- If there is a target position to reach, set it
	if target_pos ~= nil then
		self.actions.walking.target_pos = target_pos
	end

	-- Set is_walking = true
	self.actions.walking.is_walking = true

	if dir == npc.direction.north then
		vel = {x=0, y=0, z=speed}
	elseif dir == npc.direction.north_east then
		vel = {x=speed, y=0, z=speed}
	elseif dir == npc.direction.east then
		vel = {x=speed, y=0, z=0}
	elseif dir == npc.direction.south_east then
		vel = {x=speed, y=0, z=-speed}
	elseif dir == npc.direction.south then
		vel = {x=0, y=0, z=-speed}
	elseif dir == npc.direction.south_west then
		vel = {x=-speed, y=0, z=-speed}
	elseif dir == npc.direction.west then
		vel = {x=-speed, y=0, z=0}
	elseif dir == npc.direction.north_west then
		vel = {x=-speed, y=0, z=speed}
	end
	-- Rotate NPC
	npc.actions.rotate(self, {dir=dir})
	-- Set velocity so that NPC walks
	self.object:setvelocity(vel)
	-- Set walk animation
	self.object:set_animation({
			x = npc.ANIMATION_WALK_START,
			y = npc.ANIMATION_WALK_END},
			self.animation.speed_normal, 0)
end

-- This action makes the NPC stand and remain like that
function npc.actions.stand(self, args)
	local pos = args.pos
	local dir = args.dir
	-- Set is_walking = true
		self.actions.walking.is_walking = false
	-- Stop NPC
	self.object:setvelocity({x=0, y=0, z=0})
	-- If position given, set to that position
	if pos ~= nil then
		self.object:moveto(pos)
	end
		-- If dir given, set to that dir
	if dir ~= nil then
		npc.actions.rotate(self, {dir=dir})
	end
	-- Set stand animation
	self.object:set_animation({
				x = npc.ANIMATION_STAND_START,
				y = npc.ANIMATION_STAND_END},
				self.animation.speed_normal, 0)
end

-- This action makes the NPC sit on the node where it is
function npc.actions.sit(self, args)
	local pos = args.pos 
	local dir = args.dir
	-- Stop NPC
	self.object:setvelocity({x=0, y=0, z=0})
	-- If position given, set to that position
	if pos ~= nil then
		self.object:moveto(pos)
	end
	-- If dir given, set to that dir
	if dir ~= nil then
		npc.actions.rotate(self, {dir=dir})
	end
	-- Set sit animation
	self.object:set_animation({
				x = npc.ANIMATION_SIT_START,
				y = npc.ANIMATION_SIT_END},
				self.animation.speed_normal, 0)
end

-- This action makes the NPC lay on the node where it is
function npc.actions.lay(self, args)
	local pos = args.pos
	-- Stop NPC
	self.object:setvelocity({x=0, y=0, z=0})
	-- If position give, set to that position
	if pos ~= nil then
		self.object:moveto(pos)
	end
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
function npc.actions.put_item_on_external_inventory(self, args)
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

function npc.actions.take_item_from_external_inventory(self, args)
	local player = args.player
	local pos = args.pos
	local inv_list = args.inv_list
	local item_name = args.item_name
	local count = args.count
	local inv
	if player ~= nil then
		inv = minetest.get_inventory({type="player", name=player})
	else
		inv = minetest.get_inventory({type="node", pos=pos})
	end
	-- Create ItemStack to take from external inventory
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

function npc.actions.check_external_inventory_contains_item(self, args)
	local player = args.player
	local pos = args.pos
	local inv_list = args.inv_list
	local item_name = args.item_name
	local count = args.count
	local inv
	if player ~= nil then
		inv = minetest.get_inventory({type="player", name=player})
	else
		inv = minetest.get_inventory({type="node", pos=pos})
	end

	-- Create ItemStack for checking the external inventory
	local item = ItemStack(item_name.." "..count)
	-- Check if inventory contains item
	return inv:contains_item(inv_list, item)
end

-- TODO: Refactor this function so that it uses a table to check
-- for doors instead of having separate logic for each door type
function npc.actions.get_openable_node_state(node, npc_dir)
	--minetest.log("Node name: "..dump(node.name))
	local state = npc.actions.const.doors.state.CLOSED
	-- Check for default doors and gates
	local a_i1, a_i2 = string.find(node.name, "_a")
	-- Check for cottages gates
	local open_i1, open_i2 = string.find(node.name, "_close")
	-- Check for cottages half door
	local half_door_is_closed = false
	if node.name == "cottages:half_door" then
		half_door_is_closed = (node.param2 + 2) % 4 == npc_dir
	end
	if a_i1 == nil and open_i1 == nil and not half_door_is_closed then
		state = npc.actions.const.doors.state.OPEN
	end
	--minetest.log("Door state: "..dump(state))
	return state
end

-- This function is used to open or close openable nodes.
-- Currently supported openable nodes are: any doors using the
-- default doors API, and the cottages mod gates and doors. 
function npc.actions.use_openable(self, args)
	local pos = args.pos
	local action = args.action
	local dir = args.dir
	local node = minetest.get_node(pos)
	local state = npc.actions.get_openable_node_state(node, dir)

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
-- items from a chest, are provided here.

local function get_pos_argument(self, pos, use_access_node)
	--minetest.log("Type of pos: "..dump(type(pos)))
	-- Check which type of position argument we received
	if type(pos) == "table" then
		--minetest.log("Received table pos: "..dump(pos))
		-- Check if table is position
		if pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
			-- Position received, return position
			return pos
		elseif pos.place_type ~= nil then
			-- Received table in the following format: 
			-- {place_type = "", index = 1, use_access_node = false}
			local index = pos.index or 1
			local use_access_node = pos.use_access_node or false
			local places = npc.places.get_by_type(self, pos.place_type)
			-- Check index is valid on the places map
			if #places >= index then
				-- Check if access node is desired
				if use_access_node then
					-- Return actual node pos
					return places[index].access_node
				else
					-- Return node pos that allows access to node
					return places[index].pos
				end
			end
		end
	elseif type(pos) == "string" then
		-- Received name of place, so we are going to look for the actual pos
		local places_pos = npc.places.get_by_type(self, pos)
		-- Return nil if no position found
		if places_pos == nil or #places_pos == 0 then
			return nil
		end
		-- Check if received more than one position
		if #places_pos > 1 then
			-- Check all places, return owned if existent, else return the first one
			for i = 1, #places_pos do
				if places_pos[i].status == "owned" then
					if use_access_node then
						return places_pos[i].access_node
					else
						return places_pos[i].pos
					end
				end
			end
		end
		-- Return the first position only if it couldn't find an owned
		-- place, or if it there is only one
		if use_access_node then
			return places_pos[1].access_node
		else
			return places_pos[1].pos
		end
	end
end

-- This function allows a NPC to use a furnace using only items from
-- its own inventory. Fuel is not provided. Once the furnace is finished
-- with the fuel items the NPC will take whatever was cooked and whatever
-- remained to cook. The function received the position of the furnace
-- to use, and the item to cook in furnace. Item is an itemstring
function npc.actions.use_furnace(self, args)
	local pos = get_pos_argument(self, args.pos)
	if pos == nil then
		npc.log("WARNING", "Got nil position in 'use_furnace' using args.pos: "..dump(args.pos))
		return
	end

	local item = args.item
	local freeze = args.freeze
	-- Define which items are usable as fuels. The NPC
	-- will mainly use this as fuels to avoid getting useful
	-- items (such as coal lumps) for burning
	local fuels = {"default:leaves", 
					"default:pine_needles",
					"default:tree",
					"default:acacia_tree",
					"default:aspen_tree",
					"default:jungletree",
					"default:pine_tree",
					"default:coalblock",
					"farming:straw"}

	-- Check if NPC has item to cook
	local src_item = npc.inventory_contains(self, npc.get_item_name(item))
	if src_item == nil then
		-- Unable to cook item that is not in inventory
		return false
	end

	-- Check if NPC has a fuel item
	for i = 1,9 do
		local fuel_item = npc.inventory_contains(self, fuels[i]) 
	
		if fuel_item ~= nil then
			-- Get fuel item's burn time
			local fuel_time = 
			minetest.get_craft_result({method="fuel", width=1, items={ItemStack(fuel_item.item_string)}}).time 
			local total_fuel_time = fuel_time * npc.get_item_count(fuel_item.item_string)
			npc.log("DEBUG", "Fuel time: "..dump(fuel_time))

			-- Get item to cook's cooking time
			local cook_result = 
			minetest.get_craft_result({method="cooking", width=1, items={ItemStack(src_item.item_string)}})
			local total_cook_time = cook_result.time * npc.get_item_count(item)
			npc.log("DEBUG", "Cook: "..dump(cook_result))

			npc.log("DEBUG", "Total cook time: "..total_cook_time
				..", total fuel burn time: "..dump(total_fuel_time))

			-- Check if there is enough fuel to cook all items
			if total_cook_time > total_fuel_time then
				-- Don't have enough fuel to cook item. Return the difference
				-- so it may help on trying to acquire the fuel later.
				-- NOTE: Yes, returning here means that NPC could probably have other 
				-- items usable as fuels and ignore them. This should be ok for now,
				-- considering that fuel items are ordered in a way where cheaper, less
				-- useless items come first, saving possible valuable items.
				return cook_result.time - fuel_time
			end

			-- Calculate how much fuel is needed
			local fuel_amount = total_cook_time / fuel_time
			if fuel_amount < 1 then
				fuel_amount = 1
			end

			npc.log("DEBUG", "Amount of fuel needed: "..fuel_amount)

			-- Put this item on the fuel inventory list of the furnace
			local args = {
				 player = nil, 
				 pos = pos, 
				 inv_list = "fuel",
				 item_name = npc.get_item_name(fuel_item.item_string),
				 count = fuel_amount
			}
			npc.add_action(self, npc.actions.cmd.PUT_ITEM, args)
			-- Put the item that we want to cook on the furnace
			args = {
				 player = nil, 
				 pos = pos, 
				 inv_list = "src",
				 item_name = npc.get_item_name(src_item.item_string),
				 count = npc.get_item_count(item),
				 is_furnace = true
			}
			npc.add_action(self, npc.actions.cmd.PUT_ITEM, args)

			-- Now, set NPC to wait until furnace is done.
			npc.log("DEBUG", "Setting wait action for "..dump(total_cook_time))
			npc.add_action(self, npc.actions.cmd.SET_INTERVAL, {interval=total_cook_time, freeze=freeze})

			-- Reset timer
			npc.add_action(self, npc.actions.cmd.SET_INTERVAL, {interval=1, freeze=true})

			-- If freeze is false, then we will have to find the way back to the furnace
			-- once cooking is done.
			if freeze == false then
				npc.log("DEBUG", "Adding walk to position to wandering: "..dump(pos))
				npc.add_task(self, npc.actions.cmd.WALK_TO_POS, {end_pos=pos, walkable={}})
			end

			-- Take cooked items back
			args = {
				 
				 player = nil, 
				 pos = pos, 
				 inv_list = "dst",
				 item_name = cook_result.item:get_name(),
				 count = npc.get_item_count(item),
				 is_furnace = false
			}
			npc.log("DEBUG", "Taking item back: "..minetest.pos_to_string(pos))
			npc.add_action(self, npc.actions.cmd.TAKE_ITEM, args)

			npc.log("DEBUG", "Inventory: "..dump(self.inventory))

			return true
		end
	end
	-- Couldn't use the furnace due to lack of items
	return false
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, action can be lay or get up
function npc.actions.use_bed(self, args)
	local pos = get_pos_argument(self, args.pos)
	if pos == nil then
		npc.log("WARNING", "Got nil position in 'use_bed' using args.pos: "..dump(args.pos))
		return
	end
	local action = args.action
	local node = minetest.get_node(pos)
	--minetest.log(dump(node))
	local dir = minetest.facedir_to_dir(node.param2)

	if action == npc.actions.const.beds.LAY then
		-- Get position
		-- Error here due to ignore. Need to come up with better solution
		if node.name == "ignore" then
			return
		end
		local bed_pos = npc.actions.nodes.beds[node.name].get_lay_pos(pos, dir)
		-- Sit down on bed, rotate to correct direction
		npc.add_action(self, npc.actions.cmd.SIT, {pos=bed_pos, dir=(node.param2 + 2) % 4})
		-- Lay down 
		npc.add_action(self, npc.actions.cmd.LAY, {})
	else
		-- Calculate position to get up
		-- Error here due to ignore. Need to come up with better solution
		if node.name == "ignore" then
			return
		end
		local bed_pos_y = npc.actions.nodes.beds[node.name].get_lay_pos(pos, dir).y
		local bed_pos = {x = pos.x, y = bed_pos_y, z = pos.z} 
		-- Sit up
		npc.add_action(self, npc.actions.cmd.SIT, {pos=bed_pos})
		-- Initialize direction: Default is front of bottom of bed
		local dir = (node.param2 + 2) % 4
		-- Find empty node around node
		-- Take into account that mats are close to the floor, so y adjustmen is zero
		local y_adjustment = -1
		if npc.actions.nodes.beds[node.name].type == "mat" then
			y_adjustment = 0
		end
		local empty_nodes = npc.places.find_node_orthogonally(bed_pos, {"air", "cottages:bench"}, y_adjustment)
		if empty_nodes ~= nil then
			-- Get direction to the empty node
			dir = npc.actions.get_direction(bed_pos, empty_nodes[1].pos)
		end
		-- Calculate position to get out of bed
		local pos_out_of_bed =
			{x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
		-- Account for benches if they are present to avoid standing over them
		if empty_nodes[1].name == "cottages:bench" then
			pos_out_of_bed = {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
			if empty_nodes[1].param2 == 0 then
				pos_out_of_bed.z = pos_out_of_bed.z - 0.3
			elseif empty_nodes[1].param2 == 1 then
				pos_out_of_bed.x = pos_out_of_bed.x - 0.3
			elseif empty_nodes[1].param2 == 2 then
				pos_out_of_bed.z = pos_out_of_bed.z + 0.3
			elseif empty_nodes[1].param2 == 3 then
				pos_out_of_bed.x = pos_out_of_bed.x + 0.3
			end
		end
		-- Stand out of bed
		npc.add_action(self, npc.actions.cmd.STAND, {pos=pos_out_of_bed, dir=dir})
	end
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, action can be lay or get up
function npc.actions.use_sittable(self, args)
	local pos = get_pos_argument(self, args.pos)
	if pos == nil then
		npc.log("WARNING", "Got nil position in 'use_sittable' using args.pos: "..dump(args.pos))
		return
	end
	local action = args.action
	local node = minetest.get_node(pos)

	if action == npc.actions.const.sittable.SIT then
		-- Calculate position depending on bench
		-- Error here due to ignore. Need to come up with better solution
		if node.name == "ignore" then
			return
		end
		local sit_pos = npc.actions.nodes.sittable[node.name].get_sit_pos(pos, node.param2)
		-- Sit down on bench/chair/stairs
		npc.add_action(self, npc.actions.cmd.SIT, {pos=sit_pos, dir=(node.param2 + 2) % 4})
	else
		-- Find empty areas around chair
		local dir = node.param2 + 2 % 4
		-- Default it to the current position in case it can't find empty
		-- position around sittable node. Weird
		local pos_out_of_sittable = pos
		local empty_nodes = npc.places.find_node_orthogonally(pos, {"air"}, 0)
		if empty_nodes ~= nil and #empty_nodes > 0 then
			--minetest.log("Empty nodes: "..dump(empty_nodes))
			--minetest.log("Npc.actions.get_direction: "..dump(npc.actions.get_direction))
			--minetest.log("Pos: "..dump(pos))
			-- Get direction to the empty node
			dir = npc.actions.get_direction(pos, empty_nodes[1].pos)
			-- Calculate position to get out of sittable node
			pos_out_of_sittable =
			{x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
		end
		-- Stand
		npc.add_action(self, npc.actions.cmd.STAND, {pos=pos_out_of_sittable, dir=dir})
	end
end

-- This function returns the direction enum
-- for the moving from v1 to v2
function npc.actions.get_direction(v1, v2)
	local dir = vector.subtract(v2, v1)

	if dir.x ~= 0 and dir.z ~= 0 then
		if dir.x > 0 and dir.z > 0 then
			return npc.direction.north_east
		elseif dir.x > 0 and dir.z < 0 then
			return npc.direction.south_east
		elseif dir.x < 0 and dir.z > 0 then
			return npc.direction.north_west
		elseif dir.x < 0 and dir.z < 0 then
			return npc.direction.south_west
		end
	elseif dir.x ~= 0 and dir.z == 0 then
		if dir.x > 0 then
			return npc.direction.east
		else
			return npc.direction.west
		end
	elseif dir.z ~= 0 and dir.x == 0 then
		if dir.z > 0 then
			return npc.direction.north
		else
			return npc.direction.south
		end
	end
end


-- This function can be used to make the NPC walk from one
-- position to another. If the optional parameter walkable_nodes
-- is included, which is a table of node names, these nodes are
-- going to be considered walkable for the algorithm to find a
-- path.
function npc.actions.walk_to_pos(self, args)
	-- Get arguments for this task 
	local end_pos = get_pos_argument(self, args.end_pos, args.use_access_node)
	if end_pos == nil then
		npc.log("WARNING", "Got nil position in 'walk_to_pos' using args.pos: "..dump(args.end_pos))
		return
	end
	local enforce_move = args.enforce_move or true
	local walkable_nodes = args.walkable

	-- Round start_pos to make sure it can find start and end
	local start_pos = vector.round(self.object:getpos())
	-- Use y of end_pos (this can only be done assuming flat terrain)
	--start_pos.y = self.object:getpos().y
	npc.log("DEBUG", "walk_to_pos: Start pos: "..minetest.pos_to_string(start_pos))
	npc.log("DEBUG", "walk_to_pos: End pos: "..minetest.pos_to_string(end_pos))

	-- Set walkable nodes to empty if the parameter hasn't been used
	if walkable_nodes == nil then
		walkable_nodes = {}
	end

	-- Find path
	local path = npc.pathfinder.find_path(start_pos, end_pos, self, true)

	if path ~= nil and #path > 1 then
		npc.log("INFO", "walk_to_pos Found path to node: "..minetest.pos_to_string(end_pos))
		-- Store path
		self.actions.walking.path = path

		-- Local variables
		local door_opened = false
		local speed = npc.actions.two_nps_speed

		-- Set the action timer interval to half second. This is to account for
		-- the increased speed when walking.
		npc.add_action(self, npc.actions.cmd.SET_INTERVAL, {interval=0.5, freeze=true})

		-- Set the initial last and target positions
		self.actions.walking.target_pos = path[1].pos

		-- Add steps to path
		for i = 1, #path do
			-- Do not add an extra step if reached the goal node
			if (i+1) == #path then
				-- Add direction to last node
				local dir = npc.actions.get_direction(path[i].pos, end_pos)
				-- Add the last step
				npc.add_action(self, npc.actions.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+1].pos})
				-- Add stand animation at end
				npc.add_action(self, npc.actions.cmd.STAND, {dir = dir})
				break
			end
			-- Get direction to move from path[i] to path[i+1]
			local dir = npc.actions.get_direction(path[i].pos, path[i+1].pos)
			-- Check if next node is a door, if it is, open it, then walk
			if path[i+1].type == npc.pathfinder.node_types.openable then
				-- Check if door is already open
				local node = minetest.get_node(path[i+1].pos)
				if npc.actions.get_openable_node_state(node, dir) == npc.actions.const.doors.state.CLOSED then
					--minetest.log("Opening action to open door")
					-- Stop to open door, this avoids misplaced movements later on
					npc.add_action(self, npc.actions.cmd.STAND, {dir=dir})
					-- Open door
					npc.add_action(self, npc.actions.cmd.USE_OPENABLE, {pos=path[i+1].pos, dir=dir, action=npc.actions.const.doors.action.OPEN})

					door_opened = true
				end

			end

			-- Add walk action to action queue
			npc.add_action(self, npc.actions.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+1].pos})

			if door_opened then
				-- Stop to close door, this avoids misplaced movements later on
				-- local x_adj, z_adj = 0, 0
				-- if dir == 0 then
				-- 	z_adj = 0.1
				-- elseif dir == 1 then
				-- 	x_adj = 0.1
				-- elseif dir == 2 then
				-- 	z_adj = -0.1
				-- elseif dir == 3 then
				-- 	x_adj = -0.1
				-- end
				-- local pos_on_close = {x=path[i+1].pos.x + x_adj, y=path[i+1].pos.y + 1, z=path[i+1].pos.z + z_adj}
				-- Add extra walk step to ensure that one is standing at other side of openable node
				-- npc.add_action(self, npc.actions.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+2].pos})
				-- Stop to close the door
				npc.add_action(self, npc.actions.cmd.STAND, {dir=(dir + 2) % 4 })--, pos=pos_on_close})
				-- Close door
				npc.add_action(self, npc.actions.cmd.USE_OPENABLE, {pos=path[i+1].pos, action=npc.actions.const.doors.action.CLOSE})

				door_opened = false
			end

		end

		-- Return the action interval to default interval of 1 second
		-- By default, always freeze.
		npc.add_action(self, npc.actions.cmd.SET_INTERVAL, {interval=1, freeze=true})

	else
		-- Unable to find path
		npc.log("WARNING", "walk_to_pos Unable to find path. Teleporting to: "..minetest.pos_to_string(end_pos))
		-- Check if movement is enforced
		if enforce_move then
			-- Move to end pos
			self.object:moveto({x=end_pos.x, y=end_pos.y+1, z=end_pos.z})
		end 
	end
end