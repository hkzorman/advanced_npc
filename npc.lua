-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 

local S = mobs.intllib

npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"

npc.age = {
  adult = "adult",
  child = "child"
}

npc.INVENTORY_ITEM_MAX_STACK = 99

npc.ANIMATION_STAND_START = 0
npc.ANIMATION_STAND_END = 79
npc.ANIMATION_SIT_START = 81
npc.ANIMATION_SIT_END = 160
npc.ANIMATION_LAY_START = 162
npc.ANIMATION_LAY_END = 166
npc.ANIMATION_WALK_START = 168
npc.ANIMATION_WALK_END = 187
npc.ANIMATION_MINE_START = 189
npc.ANIMATION_MINE_END =198

npc.direction = {
  north = 0,
  east  = 1,
  south = 2,
  west  = 3,
  north_east = 4,
  north_west = 5,
  south_east = 6,
  south_west = 7
}

npc.action_state = {
  none = 0,
  executing = 1,
  interrupted = 2
}

npc.log_level = {
  INFO = true,
  WARNING = true,
  ERROR = true,
  DEBUG = false
}

npc.texture_check = {
  timer = 0,
  interval = 2
}

---------------------------------------------------------------------------------------
-- General functions
---------------------------------------------------------------------------------------
-- Logging
function npc.log(level, message)
  if npc.log_level[level] then
	minetest.log("[advanced_npc] "..level..": "..message)
  end
end

-- NPC chat
function npc.chat(npc_name, player_name, message)
  minetest.chat_send_player(player_name, npc_name..": "..message)
end

-- Gets name of player or NPC
function npc.get_entity_name(entity)
  if entity:is_player() then
	return entity:get_player_name()
  else
	return entity:get_luaentity().name
  end
end

-- Returns the item "wielded" by player or NPC
-- TODO: Implement NPC
function npc.get_entity_wielded_item(entity)
  if entity:is_player() then
	return entity:get_wielded_item()
  end
end

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------
-- These functions are used at spawn time to determine several
-- random attributes for the NPC in case they are not already
-- defined. On a later phase, pre-defining many of the NPC values
-- will be allowed.

local function get_random_name(sex)
  local i = math.random(#npc.data.FIRST_NAMES[sex])
  return npc.data.FIRST_NAMES[sex][i]
end

local function initialize_inventory()
  return {
	[1] = "",  [2] = "",  [3] = "",  [4] = "",
	[5] = "",  [6] = "",  [7] = "",  [8] = "",
	[9] = "",  [10] = "", [11] = "", [12] = "",
	[13] = "", [14] = "", [15] = "", [16] = "",
  }
end

-- This function checks for "female" text on the texture name
local function is_female_texture(textures)
  for i = 1, #textures do
	if string.find(textures[i], "female") ~= nil then
	  return true
	end
  end
  return false
end

local function get_random_texture(sex, age)
  local textures = {}
  local filtered_textures = {}
	-- Find textures by sex and age
  if age == npc.age.adult then
		--minetest.log("Registered: "..dump(minetest.registered_entities["advanced_npc:npc"]))
		textures = minetest.registered_entities["advanced_npc:npc"].texture_list
  elseif age == npc.age.child then
		textures = minetest.registered_entities["advanced_npc:npc"].child_texture
  end

  for i = 1, #textures do
	local current_texture = textures[i][1]
	if (sex == npc.MALE 
		and string.find(current_texture, sex) 
		and not string.find(current_texture, npc.FEMALE))
	or (sex == npc.FEMALE 
		and string.find(current_texture, sex)) then
	  table.insert(filtered_textures, current_texture)
	end
  end

  -- Check if filtered textures is empty
  if filtered_textures == {} then
	return textures[1][1]
  end

  return filtered_textures[math.random(1,#filtered_textures)]
end

function npc.get_random_texture_from_array(age, sex, textures)
	local filtered_textures = {}

	for i = 1, #textures do
		local current_texture = textures[i]
		-- Filter by age
		if (sex == npc.MALE 
				and string.find(current_texture, sex) 
				and not string.find(current_texture, npc.FEMALE)
				and ((age == npc.age.adult 
							and not string.find(current_texture, npc.age.child))
					or (age == npc.age.child
							and string.find(current_texture, npc.age.child))
					)
				)
			or (sex == npc.FEMALE 
				and string.find(current_texture, sex)
				and ((age == npc.age.adult 
							and not string.find(current_texture, npc.age.child))
					or (age == npc.age.child
							and string.find(current_texture, npc.age.child))
					)
				) then
	  				table.insert(filtered_textures, current_texture)
		end
  end

  -- Check if there are no textures
  if #filtered_textures == 0 then
  	return nil
  end

  return filtered_textures[math.random(1, #filtered_textures)]
end

-- Choose whether NPC can have relationships. Only 30% of NPCs 
-- cannot have relationships
local function can_have_relationships(is_child)
  -- Children can't have relationships
  if is_child then
	return false
  end
  local chance = math.random(1,10)
  return chance > 3
end

-- Choose a maximum of two items that the NPC will have at spawn time
-- These items are chosen from the favorite items list.
local function choose_spawn_items(self)
  local number_of_items_to_add = math.random(1, 2)
  local number_of_items = #npc.FAVORITE_ITEMS[self.sex].phase1
  
  for i = 1, number_of_items_to_add do
	npc.add_item_to_inventory(
	   self,
	   npc.FAVORITE_ITEMS[self.sex].phase1[math.random(1, number_of_items)].item, 
	   math.random(1,5)
	  )
  end
  -- Add currency to the items spawned with. Will add 5-10 tier 3
  -- currency items
  local currency_item_count = math.random(5, 10)
  npc.add_item_to_inventory(self, npc.trade.prices.currency.tier3.string, currency_item_count)

  -- For test
  --npc.add_item_to_inventory(self, "default:tree", 10)
  --npc.add_item_to_inventory(self, "default:cobble", 10)
  --npc.add_item_to_inventory(self, "default:diamond", 2)
  --npc.add_item_to_inventory(self, "default:mese_crystal", 2)
  --npc.add_item_to_inventory(self, "flowers:rose", 2)
  --npc.add_item_to_inventory(self, "advanced_npc:marriage_ring", 2)
  --npc.add_item_to_inventory(self, "flowers:geranium", 2)
  --npc.add_item_to_inventory(self, "mobs:meat", 2)
  --npc.add_item_to_inventory(self, "mobs:leather", 2)
  --npc.add_item_to_inventory(self, "default:sword_stone", 2)
  --npc.add_item_to_inventory(self, "default:shovel_stone", 2)
  --npc.add_item_to_inventory(self, "default:axe_stone", 2)

  --minetest.log("Initial inventory: "..dump(self.inventory))
end

-- Spawn function. Initializes all variables that the
-- NPC will have and choose random, starting values
function npc.initialize(entity, pos, is_lua_entity, npc_stats, occupation_name)
	npc.log("INFO", "Initializing NPC at "..minetest.pos_to_string(pos))

  	-- Get variables
  	local ent = entity
  	if not is_lua_entity then
		ent = entity:get_luaentity()
  	end

  	-- Avoid NPC to be removed by mobs_redo API
  	ent.remove_ok = false
  
  	-- Determine sex and age
  	-- If there's no previous NPC data, sex and age will be randomly chosen.
  	--   - Sex: Female or male will have each 50% of spawning
  	--   - Age: 90% chance of spawning adults, 10% chance of spawning children.
  	-- If there is previous data then:
  	--   - Sex: The unbalanced sex will get a 75% chance of spawning
  	--          - Example: If there's one male, then female will have 75% spawn chance.
  	--          -          If there's male and female, then each have 50% spawn chance.
  	--   - Age: For each two adults, the chance of spawning a child next will be 50%
  	--          If there's a child for two adults, the chance of spawning a child goes to
  	--          40% and keeps decreasing unless two adults have no child.
	-- Use NPC stats if provided	
	if npc_stats then
  		-- Default chances
		local male_s, male_e = 0, 50
		local female_s, female_e = 51, 100
		local adult_s, adult_e = 0, 85
		local child_s, child_e = 86, 100
		-- Determine sex probabilities
		if npc_stats[npc.FEMALE].total > npc_stats[npc.MALE].total then
			male_e = 75
		  	female_s, female_e = 76, 100
		elseif npc_stats[npc.FEMALE].total < npc_stats[npc.MALE].total then
			male_e = 25
			female_s, female_e = 26, 100
		end
		-- Determine age probabilities
		if npc_stats["adult_total"] >= 2 then
			if npc_stats["adult_total"] % 2 == 0 
				and (npc_stats["adult_total"] / 2 > npc_stats["child_total"]) then
					child_s,child_e = 26, 100
					adult_e = 25
			else
				child_s, child_e = 61, 100
				adult_e = 60
		  	end
		end
		-- Get sex and age based on the probabilities
		local sex_chance = math.random(1, 100)
		local age_chance = math.random(1, 100)
		local selected_sex = ""
		local selected_age = ""
		-- Select sex
		if male_s <= sex_chance and sex_chance <= male_e then
			selected_sex = npc.MALE
		elseif female_s <= sex_chance and sex_chance <= female_e then
			selected_sex = npc.FEMALE
		end
		-- Set sex for NPC
		ent.sex = selected_sex
		-- Select age
		if adult_s <= age_chance and age_chance <= adult_e then
			selected_age = npc.age.adult
		elseif child_s <= age_chance and age_chance <= child_e then
			selected_age = npc.age.child
			ent.visual_size = {
				x = 0.65,
				y = 0.65
		  	}
		  	ent.collisionbox = {-0.10,-0.50,-0.10, 0.10,0.40,0.10}
		  	ent.is_child = true
		 	-- For mobs_redo
		  	ent.child = true  
		end
		-- Store the selected age
		ent.age = selected_age

		-- Set texture accordingly
		local selected_texture = get_random_texture(selected_sex, selected_age)
		--minetest.log("Selected texture: "..dump(selected_texture))
		-- Store selected texture due to the need to restore it later
		ent.selected_texture = selected_texture
		-- Set texture and base texture
		ent.textures = {selected_texture}
		ent.base_texture = {selected_texture}
	else
		-- Get sex based on texture. This is a 50% chance for
		-- each sex as there's same amount of textures for male and female.
		-- Do not spawn child as first NPC
		if (is_female_texture(ent.base_texture)) then
			ent.sex = npc.FEMALE
		else
			ent.sex = npc.MALE
		end
		ent.age = npc.age.adult
	end

  	-- Nametag is initialized to blank
  	ent.nametag = ""

  	-- Set name
  	ent.npc_name = get_random_name(ent.sex)

  	-- Set ID
  	ent.npc_id = tostring(math.random(1000, 9999))..":"..ent.npc_name
  
  	-- Initialize all gift data
  	ent.gift_data = {
		-- Choose favorite items. Choose phase1 per default
		favorite_items = npc.relationships.select_random_favorite_items(ent.sex, "phase1"),
		-- Choose disliked items. Choose phase1 per default
		disliked_items = npc.relationships.select_random_disliked_items(ent.sex),
  }
  
  -- Flag that determines if NPC can have a relationship
  ent.can_have_relationship = can_have_relationships(ent.is_child)

  --ent.infotext = "Interested in relationships: "..dump(ent.can_have_relationship)

  -- Flag to determine if NPC can receive gifts
  ent.can_receive_gifts = ent.can_have_relationship

  -- Initialize relationships object
  ent.relationships = {}

  -- Determines if NPC is married or not
  ent.is_married_to = nil

  -- Initialize dialogues
  ent.dialogues = npc.dialogue.select_random_dialogues_for_npc(ent, "phase1")
  
  -- Declare NPC inventory
  ent.inventory = initialize_inventory()

  -- Choose items to spawn with
  choose_spawn_items(ent)

  -- Flags: generic booleans or functions that help drive functionality
  ent.flags = {}

  -- Declare trade data
  ent.trader_data = {
	-- Type of trader
	trader_status = npc.trade.get_random_trade_status(),
	-- Current buy offers
	buy_offers = {},
	-- Current sell offers
	sell_offers = {},
	-- Items to buy change timer
	change_offers_timer = 0,
	-- Items to buy change timer interval
	change_offers_timer_interval = 60,
	-- Trading list: a list of item names the trader is expected to trade in.
	-- It is mostly related to its occupation.
	-- If empty, the NPC will revert to casual trading
	-- If not, it will try to sell those that it have, and buy the ones it not.
	trade_list = {
	  sell = {},
	  buy = {},
	  both = {}
	},
	-- Custom trade allows to specify more than one payment
	-- and a custom prompt (instead of the usual buy or sell prompts)
	custom_trades = {}
  }

  -- Initialize trading offers for NPC
  --npc.trade.generate_trade_offers_by_status(ent)
  -- if ent.trader_data.trader_status == npc.trade.CASUAL then
  --   select_casual_trade_offers(ent)
  -- end

  -- Actions data
  ent.actions = {
	-- The queue is a queue of actions to be performed on each interval
	queue = {},
	-- Current value of the action timer
	action_timer = 0,
	-- Determines the interval for each action in the action queue
	-- Default is 1. This can be changed via actions
	action_interval = npc.actions.default_interval,
	-- Avoid the execution of the action timer
	action_timer_lock = false,
	-- Defines the state of the current action
	current_action_state = npc.action_state.none,
	-- Store information about action on state before lock
	state_before_lock = {
	  -- State of the mobs_redo API
	  freeze = false,
	  -- State of execution
	  action_state = npc.action_state.none,
	  -- Action executed while on lock
	  interrupted_action = {}
	},
		-- Walking variables -- required for implementing accurate movement code
		walking = {
			-- Defines whether NPC is walking to specific position or not
			is_walking = false,
			-- Path that the NPC is following
			path = {},
			-- Target position the NPC is supposed to walk to in this step. NOTE: 
			-- This is NOT the end of the path, but the next position in the path
			-- relative to the last position
			target_pos = {}
		}
  }

  -- This flag is checked on every step. If it is true, the rest of 
  -- Mobs Redo API is not executed
  ent.freeze = nil

  -- This map will hold all the places for the NPC
  -- Map entries should be like: "bed" = {x=1, y=1, z=1}
  ent.places_map = {}

  	-- Schedule data
  	ent.schedules = {
		-- Flag to enable or disable the schedules functionality
		enabled = true, 
		-- Lock for when executing a schedule
		lock = false,
		-- Queue of schedules executed
		-- Used to calculate dependencies
		temp_executed_queue = {},
		-- An array of schedules, meant to be one per day at some point
		--- when calendars are implemented. Allows for only 7 schedules,
		-- one for each day of the week
		generic = {},
		-- An array of schedules, meant to be for specific dates in the 
		-- year. Can contain as many as possible. The keys will be strings
		-- in the format MM:DD
		date_based = {},
		-- The following holds the check parameters provided by the
		-- current schedule
		current_check_params = {}
  	}

  	-- If occupation name given, override properties with
  	-- occupation values and initialize schedules
  	minetest.log("Entity age: "..dump(ent.age)..", afult? "..dump(ent.age==npc.age.adult))
  	if occupation_name and occupation_name ~= "" and ent.age == npc.age.adult then
  		npc.occupations.initialize_occupation_values(ent, occupation_name)
  	end

  	-- TODO: Remove this - do inside occupation
  	-- Dedicated trade test
  	ent.trader_data.trade_list.both = {
		["default:tree"] = {},
		["default:cobble"] = {},
		["default:wood"] = {},
		["default:diamond"] = {},
		["default:mese_crystal"] = {},
		["flowers:rose"] = {},
		["advanced_npc:marriage_ring"] = {},
		["flowers:geranium"] = {},
		["mobs:meat"] = {},
		["mobs:leather"] = {},
		["default:sword_stone"] = {},
		["default:shovel_stone"] = {},
		["default:axe_stone"] = {}
  	}

  	-- Generate trade offers
  	npc.trade.generate_trade_offers_by_status(ent)

  	-- Add a custom trade offer
  	-- local offer1 = npc.trade.create_custom_sell_trade_offer("Do you want me to fix your steel sword?", "Fix steel sword", "Fix steel sword", "default:sword_steel", {"default:sword_steel", "default:iron_lump 5"})
  	-- table.insert(ent.trader_data.custom_trades, offer1)
  	--local offer2 = npc.trade.create_custom_sell_trade_offer("Do you want me to fix your mese sword?", "Fix mese sword", "Fix mese sword", "default:sword_mese", {"default:sword_mese", "default:copper_lump 10"})
  	--table.insert(ent.trader_data.custom_trades, offer2)

  	-- Set initialized flag on
	ent.initialized = true
  	npc.log("WARNING", "Spawned entity: "..dump(ent))
  	npc.log("INFO", "Successfully initialized NPC with name "..dump(ent.npc_name)
		..", sex: "..ent.sex..", is child: "..dump(ent.is_child)
		..", texture: "..dump(ent.textures))
  	-- Refreshes entity
  	ent.object:set_properties(ent)
end

---------------------------------------------------------------------------------------
-- Trading functions
---------------------------------------------------------------------------------------
function npc.generate_trade_list_from_inventory(self)
  local list = {}
  for i = 1, #self.inventory do
	list[npc.get_item_name(self.inventory[i])] = {}
  end
  self.trader_data.trade_list.both = list
end

function npc.set_trading_status(self, status)
  -- Set status
  self.trader_data.trader_status = status
  -- Re-generate trade offers
  npc.trade.generate_trade_offers_by_status(self)
end

---------------------------------------------------------------------------------------
-- Inventory functions
---------------------------------------------------------------------------------------
-- NPCs inventories are restrained to 16 slots.
-- Each slot can hold one item up to 99 count.

-- Utility function to get item name from a string
function npc.get_item_name(item_string)
  return ItemStack(item_string):get_name()
end

-- Utility function to get item count from a string
function npc.get_item_count(item_string)
  return ItemStack(item_string):get_count()
end

-- Add an item to inventory. Returns true if add successful
-- These function can be used to give items to other NPCs
-- given that the "self" variable can be any NPC
function npc.add_item_to_inventory(self, item_name, count)
  -- Check if NPC already has item
  local existing_item = npc.inventory_contains(self, item_name)
  if existing_item ~= nil and existing_item.item_string ~= nil then
	-- NPC already has item. Get count and see
	local existing_count = npc.get_item_count(existing_item.item_string)
	if (existing_count + count) < npc.INVENTORY_ITEM_MAX_STACK then
	  -- Set item here
	  self.inventory[existing_item.slot] = 
		npc.get_item_name(existing_item.item_string).." "..tostring(existing_count + count)
		return true
	else
	  --Find next free slot
	  for i = 1, #self.inventory do
		if self.inventory[i] == "" then
		  -- Found slot, set item
		  self.inventory[i] = 
			item_name.." "..tostring((existing_count + count) - npc.INVENTORY_ITEM_MAX_STACK)
		  return true
		end
	  end
	  -- No free slot found
	  return false
	end
  else
	-- Find a free slot
	for i = 1, #self.inventory do
	  if self.inventory[i] == "" then
		-- Found slot, set item
		self.inventory[i] = item_name.." "..tostring(count)
		return true
	  end
	end
	-- No empty slot found
	return false
  end
end

-- Same add method but with itemstring for convenience
function npc.add_item_to_inventory_itemstring(self, item_string)
  local item_name = npc.get_item_name(item_string)
  local item_count = npc.get_item_count(item_string)
  npc.add_item_to_inventory(self, item_name, item_count)
end

-- Checks if an item is contained in the inventory. Returns
-- the item string or nil if not found
function npc.inventory_contains(self, item_name)
  for key,value in pairs(self.inventory) do
	if value ~= "" and string.find(value, item_name) then
	  return {slot=key, item_string=value}
	end
  end
  -- Item not found
  return nil
end

-- Removes the item from an NPC inventory and returns the item
-- with its count (as a string, e.g. "default:apple 2"). Returns
-- nil if unable to get the item.
function npc.take_item_from_inventory(self, item_name, count)
  local existing_item = npc.inventory_contains(self, item_name)
  if existing_item ~= nil then
	-- Found item
	local existing_count = npc.get_item_count(existing_item.item_string)
	local new_count = existing_count
	if existing_count - count  < 0 then
	  -- Remove item first
	  self.inventory[existing_item.slot] = ""
	  -- TODO: Support for retrieving from next stack. Too complicated
	  -- and honestly might be unecessary.
	  return item_name.." "..tostring(new_count)
	else
	  new_count = existing_count - count
	  if new_count == 0 then
		self.inventory[existing_item.slot] = ""
	  else
		self.inventory[existing_item.slot] = item_name.." "..new_count
	  end
	  return item_name.." "..tostring(count)
	end
  else
	-- Not able to take item because not found
	return nil
  end
end

-- Same take method but with itemstring for convenience
function npc.take_item_from_inventory_itemstring(self, item_string)
  local item_name = npc.get_item_name(item_string)
  local item_count = npc.get_item_count(item_string)
  npc.take_item_from_inventory(self, item_name, item_count)
end

---------------------------------------------------------------------------------------
-- Flag functionality
---------------------------------------------------------------------------------------
-- TODO: Consider removing them as they are pretty simple and straight forward.
-- Generic variables or function that help drive some functionality for the NPC.
function npc.add_flag(self, flag_name, value)
  self.flags[flag_name] = value
end

function npc.update_flag(self, flag_name, value)
  self.flags[flag_name] = value
end

function npc.get_flag(self, flag_name)
  return self.flags[flag_name]
end

---------------------------------------------------------------------------------------
-- Dialogue functionality
---------------------------------------------------------------------------------------
function npc.start_dialogue(self, clicker, show_married_dialogue)

  -- Call dialogue function as normal
  npc.dialogue.start_dialogue(self, clicker, show_married_dialogue)

  -- Check and update relationship if needed
  npc.relationships.dialogue_relationship_update(self, clicker)

end

---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- This function adds a function to the action queue.
-- Actions should be added in strict order for tasks to work as expected.
function npc.add_action(self, action, arguments)
  local action_entry = {action=action, args=arguments, is_task=false}
  table.insert(self.actions.queue, action_entry)
end

-- This function adds task actions in-place, as opposed to
-- at the end of the queue. This allows for continued order
function npc.add_task(self, task, args)
  local action_entry = {action=task, args=args, is_task=true}
  table.insert(self.actions.queue, action_entry)
end

-- This function removes the first action in the action queue
-- and then executes it
function npc.execute_action(self)
	-- Check if an action was interrupted
  	if self.actions.current_action_state == npc.action_state.interrupted then
		npc.log("DEBUG", "Re-inserting interrupted action for NPC: '"..dump(self.npc_name).."': "..dump(self.actions.state_before_lock.interrupted_action))
		-- Insert into queue the interrupted action
		table.insert(self.actions.queue, 1, self.actions.state_before_lock.interrupted_action)
		-- Clear the action
		self.actions.state_before_lock.interrupted_action = {}
		-- Clear the position
		self.actions.state_before_lock.pos = {}
  	end
  	local result = nil
  	if table.getn(self.actions.queue) == 0 then
		-- Set state to none
		self.actions.current_action_state = npc.action_state.none
		-- Keep state the same if there are no more actions in actions queue
		return self.freeze
  	end
  	local action_obj = self.actions.queue[1]
  	-- Check if action is null
  	if action_obj.action == nil then
		return
  	end
  	-- Check if action is an schedule check
  	if action_obj.action == "schedule_check" then
  		-- Execute schedule check
  		npc.schedule_check(self)
  		-- Remove table entry
  		table.remove(self.actions.queue, 1)
  		-- Return
  		return false
  	end
  	-- If the entry is a task, then push all this new operations in
  	-- stack fashion
  	if action_obj.is_task == true then
		npc.log("DEBUG", "Executing task for NPC '"..dump(self.npc_name).."': "..dump(action_obj))
		-- Backup current queue
		local backup_queue = self.actions.queue
		-- Remove this "task" action from queue
		table.remove(self.actions.queue, 1)
		-- Clear queue
		self.actions.queue = {}
		-- Now, execute the task with its arguments
		result = npc.actions.execute(self, action_obj.action, action_obj.args)
		--result = action_obj.action(self, action_obj.args)
		-- After all new actions has been added by task, add the previously
		-- queued actions back
		for i = 1, #backup_queue do
	  		table.insert(self.actions.queue, backup_queue[i])
		end
  	else
		npc.log("DEBUG", "Executing action for NPC '"..dump(self.npc_name).."': "..dump(action_obj))
		-- Store the action that is being executed
		self.actions.state_before_lock.interrupted_action = action_obj
		-- Store current position
		self.actions.state_before_lock.pos = self.object:getpos()
		-- Execute action as normal
		result = npc.actions.execute(self, action_obj.action, action_obj.args)
		-- Remove task
		table.remove(self.actions.queue, 1)
		-- Set state
		self.actions.current_action_state = npc.action_state.executing
  	end
  	return result
end

function npc.lock_actions(self)

  -- Avoid re-locking if already locked
  if self.actions.action_timer_lock == true then
	return
  end

  local pos = self.object:getpos()

  if self.freeze == false then
	-- Round current pos to avoid the NPC being stopped on positions
	-- where later on can't walk to the correct positions
	-- Choose which position is to be taken as start position
	if self.actions.state_before_lock.pos ~= {} then
	  pos = vector.round(self.actions.state_before_lock.pos)
	else
	  pos = vector.round(self.object:getpos())
	end
	pos.y = self.object:getpos().y
  end
  -- Stop NPC
  npc.actions.execute(self, npc.actions.cmd.STAND, {pos=pos})
  -- Avoid all timer execution
  self.actions.action_timer_lock = true
  -- Reset timer so that it has some time after interaction is done
  self.actions.action_timer = 0
  -- Check if there are is an action executing
  if self.actions.current_action_state == npc.action_state.executing 
	and self.freeze == false then
	-- Store the current action state
	self.actions.state_before_lock.action_state = self.actions.current_action_state
	-- Set current action state to interrupted
	self.actions.current_action_state = npc.action_state.interrupted
  end
  -- Store the current freeze variable
  self.actions.state_before_lock.freeze = self.freeze
  -- Freeze mobs_redo API
  self.freeze = false

  npc.log("DEBUG", "Locking NPC "..dump(self.npc_id).." actions")
end

function npc.unlock_actions(self)
  -- Allow timers to execute
  self.actions.action_timer_lock = false
  -- Restore the value of self.freeze
  self.freeze = self.actions.state_before_lock.freeze
  
  if table.getn(self.actions.queue) == 0 then
	-- Allow mobs_redo API to execute since action queue is empty
	self.freeze = true
  end

  npc.log("DEBUG", "Unlocked NPC "..dump(self.npc_id).." actions")
end

---------------------------------------------------------------------------------------
-- Schedule functionality
---------------------------------------------------------------------------------------
-- Schedules allow the NPC to do different things depending on the time of the day.
-- The time of the day is in 24 hours and is consistent with the Minetest Game 
-- /time command. Hours will be written as numbers: 1 for 1:00, 13 for 13:00 or 1:00 PM
-- The API is as following: a schedule can be created for a specific date or for a
-- day of the week. A date is a string in the format MM:DD
npc.schedule_types = {
  ["generic"] = "generic",
  ["date_based"] = "date_based"
}

npc.schedule_properties = {
  put_item = "put_item",
  put_multiple_items = "put_multiple_items",
  take_item = "take_item",
  trader_status = "trader_status",
  can_receive_gifts = "can_receive_gifts"
}

local function get_time_in_hours() 
  return minetest.get_timeofday() * 24
end

-- Create a schedule on a NPC.
-- Schedule types:
--  - Generic: Returns nil if there are already
--    seven schedules, one for each day of the
--    week or if the schedule attempting to add
--    already exists. The date parameter is the 
--    day of the week it represents as follows:
--      - 1: Monday
--      - 2: Tuesday
--      - 3: Wednesday
--      - 4: Thursday
--      - 5: Friday
--      - 6: Saturday
--      - 7: Sunday
--  - Date-based: The date parameter should be a
--    string of the format "MM:DD". If it already
--    exists, function retuns nil
function npc.create_schedule(self, schedule_type, date)
  if schedule_type == npc.schedule_types.generic then
	-- Check that there are no more than 7 schedules
	if #self.schedules.generic == 7 then
	  -- Unable to add schedule
	  return nil
	elseif #self.schedules.generic < 7 then
	  -- Check schedule doesn't exists already
	  if self.schedules.generic[date] == nil then
		-- Add schedule
		self.schedules.generic[date] = {}
	  else
		-- Schedule already present
		return nil
	  end
	end
  elseif schedule_type == npc.schedule_types.date then
	-- Check schedule doesn't exists already
	if self.schedules.date_based[date] == nil then
	  -- Add schedule 
	  self.schedules.date_based[date] = {}
	else
	  -- Schedule already present
	  return nil
	end
  end
end

function npc.delete_schedule(self, schedule_type, date)
	-- Delete schedule by setting entry to nil
	self.schedules[schedule_type][date] = nil
end

-- Schedule entries API
-- Allows to add, get, update and delete entries from each
-- schedule. Attempts to be as safe-fail as possible to avoid crashes. 

-- Actions is an array of actions and tasks that the NPC
-- will perform at the scheduled time on the scheduled date
function npc.add_schedule_entry(self, schedule_type, date, time, check, actions)
	-- Check that schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Add schedule entry
		if check == nil then
			self.schedules[schedule_type][date][time] = actions
		else
			self.schedules[schedule_type][date][time].check = check
		end
	else
		-- No schedule found, need to be created for date
		return nil
	end
end

function npc.get_schedule_entry(self, schedule_type, date, time)
	-- Check if schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Return schedule
		return self.schedules[schedule_type][date][time]
	else
		-- Schedule for date not found
		return nil
	end
end

function npc.update_schedule_entry(self, schedule_type, date, time, check, actions)
	-- Check schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Check that a schedule entry for that time exists
		if self.schedules[schedule_type][date][time] ~= nil then
		  	-- Set the new actions
			if check == nil then
				self.schedules[schedule_type][date][time] = actions
			else
				self.schedules[schedule_type][date][time].check = check
			end
		else
			-- Schedule not found for specified time
			return nil
		end
	else
		-- Schedule not found for date
		return nil
	end
end

function npc.delete_schedule_entry(self, schedule_type, date, time)
	-- Check schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Remove schedule entry by setting to nil
		self.schedules[schedule_type][date][time] = nil
	else
		-- Schedule not found for date
		return nil
	end
end

function npc.schedule_change_property(self, property, args)
	if property == npc.schedule_properties.trader_status then
		-- Get status from args
		local status = args.status
		-- Set status to NPC
		npc.set_trading_status(self, status)
	elseif property == npc.schedule_properties.put_item then
		local itemstring = args.itemstring
		-- Add item
		npc.add_item_to_inventory_itemstring(self, itemstring)
	elseif property == npc.schedule_properties.put_multiple_items then
		local itemlist = args.itemlist
		for i = 1, #itemlist do
			local itemlist_entry = itemlist[i]
			local current_itemstring = itemlist[i].name
	  		if itemlist_entry.random == true then
				current_itemstring = current_itemstring
		  			.." "..dump(math.random(itemlist_entry.min, itemlist_entry.max))
	 		else
				current_itemstring = current_itemstring.." "..tostring(itemlist_entry.count)
	  		end
	  		-- Add item to inventory
	  		npc.add_item_to_inventory_itemstring(self, current_itemstring)
		end
	elseif property == npc.schedule_properties.take_item then
		local itemstring = args.itemstring
		-- Add item
		npc.take_item_from_inventory_itemstring(self, itemstring)
	elseif property == npc.schedule_properties.can_receive_gifts then
		local value = args.can_receive_gifts
		-- Set status
		self.can_receive_gifts = value
  	end
end

function npc.add_schedule_check(self)
	table.insert(self.actions.queue, {action="schedule_check", args={}, is_task=false})
end

-- Range: integer, radius in which nodes will be searched. Recommended radius is 
--		  between 1-3 
-- Nodes: array of node names
-- Actions: map of node names to entries {action=<action_enum>, args={}}. 
--			Arguments can be empty - the check function will try to determine most 
--			arguments anyways (like pos and dir).
--			Special node "any" will execute those actions on any node except the
--			already specified ones.
-- None-action: array of entries {action=<action_enum>, args={}}.
--				Will be executed when no node is found.
function npc.schedule_check(self)
	local range = self.schedules.current_check_params.range
	local nodes = self.schedules.current_check_params.nodes
	local actions = self.schedules.current_check_params.actions
	local none_actions = self.schedules.current_check_params.none_actions
	-- Get NPC position
	local start_pos = self.object:getpos()
	-- Search nodes
	local found_nodes = npc.places.find_node_nearby(start_pos, nodes, range)
	-- Check if any node was found
	if found_nodes then
		-- Pick a random node to act upon
		local node_pos = found_nodes[math.random(1, #found_nodes)]
		local node = minetest.get_node(node_pos)
		-- Set node as a place
		-- Note: Code below isn't *adding* a node, but overwriting the
		-- place with "schedule_target_pos" place type
		npc.places.add_shared_accessible_place(
			self, node, npc.places.PLACE_TYPE.SCHEDULE.TARGET, true)
		-- Get actions related to node and enqueue them
		for i = 1, #actions[node.name] do
			local args = {}
			local action = nil
			-- Calculate arguments for the following supported actions:
			--   - Dig
			--   - Place
			--   - Walk step
			--   - Walk to position
			--   - Use furnace
			if actions[node.name][i].action == npc.actions.cmd.DIG then
				-- Defaults: items will be added to inventory if not specified
				-- otherwise, and protection will be respected, if not specified
				-- otherwise
				args = {
					pos = node_pos,
					add_to_inventory = action[node.name][i].args.add_to_inventory or true,
					bypass_protection = action[node.name][i].args.bypass_protection or false
				}
			elseif actions[node.name][i].action == npc.actions.cmd.PLACE then
				-- Position: providing node_pos is because the currently planned
				-- behavior for placing nodes is replacing digged nodes. A NPC farmer,
				-- for instance, might dig a plant node and plant another one on the
				-- same position.
				-- Defaults: items will be taken from inventory if existing, 
				-- if not will be force-placed (item comes from thin air)
				-- Protection will be respected
				args = {
					pos =  action[node.name][i].args.pos or node_pos,
					source = action[node.name][i].args.source or npc.actions.take_from_inventory_forced,
					node =  action[node.name][i].args.node,
					bypass_protection =  action[node.name][i].args.bypass_protection or false
				}
			elseif actions[node.name][i].action == npc.actions.cmd.WALK_STEP then
				-- Defaults: direction is calculated from start node to node_pos.
				-- Speed is default wandering speed. Target pos is node_pos
				-- Calculate dir if dir is random
				local dir = npc.actions.get_direction(start_pos, node_pos)
				if actions[node.name][i].args.dir == "random" then
					dir = math.random(0,7)
				elseif type(actions[node.name][i].args.dir) == "number" then
					dir = actions[node.name][i].args.dir
				end
				args = {
					dir = dir,
					speed = actions[node.name][i].args.speed or npc.actions.one_nps_speed,
					target_pos = actions[node.name][i].args.target_pos or node_pos
				}
			elseif actions[node.name][i].action == npc.actions.cmd.WALK_TO_POS then
				-- Optimize walking -- since distances can be really short,
				-- a simple walk_step() action can do most of the times. For
				-- this, however, we need to calculate direction		
				-- First of all, check distance
				if vector.distance(start_pos, node_pos) < 3 then
					-- Will do walk_step based instead
					action = npc.actions.cmd.WALK_STEP
					args = {
						dir = npc.actions.get_direction(start_pos, node_pos),
						speed = npc.actions.one_nps_speed,
						target_pos = node_pos
					}
				else
					-- Set end pos to be node_pos
					args = {
						end_pos = actions[node.name][i].args.end_pos or node_pos,
						walkable = actions[node.name][i].args.walkable or {}
					}
				end
			elseif actions[node.name][i].action == npc.actions.cmd.USE_FURNACE then
				-- Defaults: pos is node_pos. Freeze is true
				args = {
					pos = actions[node.name][i].args.pos or node_pos,
					item = actions[node.name][i].args.item,
					freeze = actions[node.name][i].args.freeze or true
				}
			end
			-- Enqueue actions
			npc.add_action(self, action or actions[node.name][i].action, args or actions[node.name][i].args)
		end
		-- Enqueue next schedule check
		if self.schedules.current_check_params.execution_count 
			< self.schedules.current_check_params.execution_times then
			npc.add_schedule_check()
		end
		-- Nodes found
		return true
	else
		-- No nodes found, enqueue none_actions
		for i = 1, #none_actions do
			-- Enqueue actions
			npc.add_action(self, none_actions[i].action, none_actions[i].args)
		end
		-- Enqueue next schedule check
		if self.schedules.current_check_params.execution_count 
			< self.schedules.current_check_params.execution_times then
			npc.add_schedule_check()
		end
		-- No nodes found
		return false
	end
end

---------------------------------------------------------------------------------------
-- NPC Definition
---------------------------------------------------------------------------------------
mobs:register_mob("advanced_npc:npc", {
	type = "npc",
	passive = false,
	damage = 3,
	attack_type = "dogfight",
	attacks_monsters = true,
	-- Added group attack
	group_attack = true,
	--pathfinding = true,
	pathfinding = 1,
	hp_min = 10,
	hp_max = 20,
	armor = 100,
	collisionbox = {-0.20,0,-0.20, 0.20,1.8,0.20},
  	--collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20},
  	--collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "character.b3d",
	drawtype = "front",
	textures = {
		{"npc_male1.png"},
		{"npc_male2.png"},
		{"npc_male3.png"},
		{"npc_male4.png"},
		{"npc_male5.png"},
		{"npc_male6.png"},
		{"npc_female1.png"}, -- female by nuttmeg20
	},
	child_texture = {
		{"npc_child_male1.png"},
	  	{"npc_child_female1.png"},
  	},
	makes_footstep_sound = true,
	sounds = {},
	-- Added walk chance
	walk_chance = 30,
	-- Added stepheight
	stepheight = 0.6,
	walk_velocity = 1,
	run_velocity = 3,
	jump = false,
	drops = {
		{name = "default:wood", chance = 1, min = 1, max = 3},
		{name = "default:apple", chance = 2, min = 1, max = 2},
		{name = "default:axe_stone", chance = 5, min = 1, max = 1},
	},
	water_damage = 0,
	lava_damage = 2,
	light_damage = 0,
	--follow = {"farming:bread", "mobs:meat", "default:diamond"},
	view_range = 15,
	owner = "",
	order = "follow",
	--order = "stand",
	fear_height = 3,
	animation = {
		speed_normal = 30,
		speed_run = 30,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 200,
		punch_end = 219,
	},
	on_rightclick = function(self, clicker)

	-- Rotate NPC toward its clicker
	npc.dialogue.rotate_npc_to_player(self)

	-- Get information from clicker
		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()

	npc.log("DEBUG", "Right-clicked NPC: "..dump(self))

	-- Receive gift or start chat. If player has no item in hand
	-- then it is going to start chat directly
	--minetest.log("self.can_have_relationship: "..dump(self.can_have_relationship)..", self.can_receive_gifts: "..dump(self.can_receive_gifts)..", table: "..dump(item:to_table()))
	if self.can_have_relationship 
	  	and self.can_receive_gifts 
	 	and item:to_table() ~= nil then
	  	-- Get item name
	  	local item = minetest.registered_items[item:get_name()]
	  	local item_name = item.description

	  	-- Show dialogue to confirm that player is giving item as gift
	  	npc.dialogue.show_yes_no_dialogue(
			self,
			"Do you want to give "..item_name.." to "..self.npc_name.."?",
			npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX..item_name,
			function()
		  		npc.relationships.receive_gift(self, clicker)
			end,
			npc.dialogue.NEGATIVE_ANSWER_LABEL,
			function()
		  		npc.start_dialogue(self, clicker, true)
			end,
			name
	  	)
	else
	  npc.start_dialogue(self, clicker, true)
	end

	end,
	do_custom = function(self, dtime)
		if self.initialized == nil then
			-- Initialize NPC if spawned using the spawn egg built in from
		  	-- mobs_redo. This functionality will be removed in the future in
		  	-- favor of a better manual spawning method with customization 
		  	npc.log("WARNING", "Initializing NPC from entity step. This message should only be appearing if an NPC is being spawned from inventory with egg!")
		  	npc.initialize(self, self.object:getpos(), true)
		  	self.tamed = false
		  	self.owner = nil
		else
		  	-- NPC is initialized, check other variables
		  	-- Check child texture issues
		  	if self.is_child then
				-- Check texture 
				npc.texture_check.timer = npc.texture_check.timer + dtime
				if npc.texture_check.timer > npc.texture_check.interval then
			  		-- Reset timer
					npc.texture_check.timer = 0
			  		-- Set hornytimer to zero every 60 seconds so that children
			  		-- don't grow automatically
			  		self.hornytimer = 0
			  		-- Set correct textures
			  		self.texture = {self.selected_texture}
			  		self.base_texture = {self.selected_texture}
			  		self.object:set_properties(self)
			  		npc.log("WARNING", "Corrected textures on NPC child "..dump(self.npc_name))
			  		-- Set interval to large interval so this code isn't called frequently
			  		npc.texture_check.interval = 60
				end
		  end

		-- Timer function for casual traders to reset their trade offers  
		self.trader_data.change_offers_timer = self.trader_data.change_offers_timer + dtime
		-- Check if time has come to change offers
		if self.trader_data.trader_status == npc.trade.CASUAL and 
			self.trader_data.change_offers_timer >= self.trader_data.change_offers_timer_interval then
			-- Reset timer
			self.trader_data.change_offers_timer = 0
			-- Re-select casual trade offers
			npc.trade.generate_trade_offers_by_status(self)
		end
	  
		-- Timer function for gifts
		for i = 1, #self.relationships do
			local relationship = self.relationships[i]
			-- Gift timer check
			if relationship.gift_timer_value < relationship.gift_interval then
			  	relationship.gift_timer_value = relationship.gift_timer_value + dtime
			elseif relationship.talk_timer_value < relationship.gift_interval then
			  	-- Relationship talk timer - only allows players to increase relationship
			  	-- by talking on the same intervals as gifts
			  	relationship.talk_timer_value = relationship.talk_timer_value + dtime
			else
			  	-- Relationship decrease timer
			  	if relationship.relationship_decrease_timer_value 
				  	< relationship.relationship_decrease_interval then
					relationship.relationship_decrease_timer_value = 
				  	relationship.relationship_decrease_timer_value + dtime
			  	else
					-- Check if married to decrease half
					if relationship.phase == "phase6" then
				  		-- Avoid going below the marriage phase limit
				  		if (relationship.points - 0.5) >= 
							npc.relationships.RELATIONSHIP_PHASE["phase5"].limit then
							relationship.points = relationship.points - 0.5
				  		end
					else
				  		relationship.points = relationship.points - 1
					end
					relationship.relationship_decrease_timer_value = 0
					--minetest.log(dump(self))
			  	end
			end
		end

		-- Action queue timer
		-- Check if actions and timers aren't locked
		if self.actions.action_timer_lock == false then
			-- Increment action timer
			self.actions.action_timer = self.actions.action_timer + dtime
			if self.actions.action_timer >= self.actions.action_interval then
				-- Reset action timer
			  	self.actions.action_timer = 0
				-- Check if NPC is walking
				if self.actions.walking.is_walking == true then
					-- Move NPC to expected position to ensure not getting lost
					local pos = self.actions.walking.target_pos
					self.object:moveto({x=pos.x, y=pos.y-0.5, z=pos.z})
			  	end
			  	-- Execute action
			  	self.freeze = npc.execute_action(self)
			  	-- Check if there are still remaining actions in the queue
			  	if self.freeze == nil and table.getn(self.actions.queue) > 0 then
					self.freeze = false
			  	end
			end
		end

		-- Schedule timer
		-- Check if schedules are enabled
		if self.schedules.enabled == true then
			-- Get time of day
			local time = get_time_in_hours()
			-- Check if time is an hour
			if time % 1 < 0.1 and self.schedules.lock == false then
			  	-- Activate lock to avoid more than one entry to this code
			  	self.schedules.lock = true
			  	-- Get integer part of time
			  	time = (time) - (time % 1)
			  	-- Check if there is a schedule entry for this time
			  	-- Note: Currently only one schedule is supported, for day 0
			  	--minetest.log("Time: "..dump(time))
			  	local schedule = self.schedules.generic[0]
			  	if schedule ~= nil then
					-- Check if schedule for this time exists
					--minetest.log("Found default schedule")
					if schedule[time] ~= nil then
						npc.log("WARNING", "Found schedule for time "..dump(time)..": "..dump(schedule[time]))
							npc.log("DEBUG", "Adding actions to action queue")
							-- Add to action queue all actions on schedule
							for i = 1, #schedule[time] do
						  		-- Check if schedule has a check function
				  				if not schedule[time][i].check then
									-- Add parameters for check function and run for first time
									npc.log("INFO", "NPC "..dump(self.npc_name).." is starting check on "..minetest.pos_to_string(self.object:getpos()))
									local check_params = schedule[time][i]
									-- Calculates how many times check will be executed
									local execution_times = check_params.count
									if check_params.random_execution_times then
										execution_times = math.random(check_params.min_count, check_params.max_count)
									end
									-- Set current parameters
									self.schedules.current_check_params = {
										range = check_params.range,
										nodes = check_params.nodes, 
										actions = check_params.actions, 
										none_actions = check_params.none_actions,
										execution_count = 0,
										execution_times = execution_times
									}
									-- Execute check for the first time
									npc.schedule_check(self)
								else
									-- Run usual schedule entry
							  		-- Check chance
							  		local execution_chance = math.random(1, 100)
							  		if not schedule[time][i].chance or
										(schedule[time][i].chance and execution_chance <= schedule[time][i].chance) then
										-- Check if entry has dependency on other entry
										local dependencies_met = nil
										if schedule[time][i].depends then
											dependencies_met = npc.utils.array_is_subset_of_array(
											self.schedules.temp_executed_queue, 
											schedule[time][i].depends)
										end

										-- Check for dependencies being met
										if dependencies_met == nil or dependencies_met == true then
									  		-- Add tasks
									  		if schedule[time][i].task ~= nil then
												-- Add task
												npc.add_task(self, schedule[time][i].task, schedule[time][i].args)
									  		elseif schedule[time][i].action ~= nil then
												-- Add action
												npc.add_action(self, schedule[time][i].action, schedule[time][i].args)
									  		elseif schedule[time][i].property ~= nil then
												-- Change NPC property
												npc.schedule_change_property(self, schedule[time][i].property, schedule[time][i].args)
									  		end
									  		-- Backward compatibility check
									  		if self.schedules.temp_executed_queue then
									  			-- Add into execution queue to meet dependency
									  			table.insert(self.schedules.temp_executed_queue, i)
									  		end
										end
									else
										-- TODO: Change to debug
										npc.log("WARNING", "Skipping schedule entry for time "..dump(time)..": "..dump(schedule[time][i]))
									end
								end
							end
							-- Clear execution queue
							self.schedules.temp_executed_queue = {}
							npc.log("WARNING", "New action queue: "..dump(self.actions))
						end
					end
				end
			else
				-- Check if lock can be released
				if time % 1 > 0.1 then
					-- Release lock
					self.schedules.lock = false
			  	end
			end
		end
		  
		return self.freeze
	end
})

-- Spawn
-- mobs:spawn({
--   name = "advanced_npc:npc",
--   nodes = {"advanced_npc:plotmarker_auto_spawner", "mg_villages:plotmarker"},
--   min_light = 3,
--   active_object_count = 1,
--   interval = 5,
--   chance = 1,
--   --max_height = 0,
--   on_spawn = npc.initialize
-- })

-------------------------------------------------------------------------
-- Item definitions
-------------------------------------------------------------------------

mobs:register_egg("advanced_npc:npc", S("NPC"), "default_brick.png", 1)

-- compatibility
mobs:alias_mob("mobs:npc", "advanced_npc:npc")

-- Marriage ring
minetest.register_craftitem("advanced_npc:marriage_ring", {
	description = S("Marriage Ring"),
	inventory_image = "marriage_ring.png",
})

-- Marriage ring craft recipe
minetest.register_craft({
	output = "advanced_npc:marriage_ring",
	recipe = { {"", "", ""},
			 {"", "default:diamond", ""},
			 {"", "default:gold_ingot", ""} },
})
