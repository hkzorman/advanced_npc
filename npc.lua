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
	DEBUG = false,
	DEBUG_ACTION = false,
	DEBUG_SCHEDULE = false,
	EXECUTION = false
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

-- Simple wrapper over minetest.add_particle()
-- Copied from mobs_redo/api.lua
function npc.effect(pos, amount, texture, min_size, max_size, radius, gravity, glow)

	radius = radius or 2
	min_size = min_size or 0.5
	max_size = max_size or 1
	gravity = gravity or -10
	glow = glow or 0

	minetest.add_particlespawner({
		amount = amount,
		time = 0.25,
		minpos = pos,
		maxpos = pos,
		minvel = {x = -radius, y = -radius, z = -radius},
		maxvel = {x = radius, y = radius, z = radius},
		minacc = {x = 0, y = gravity, z = 0},
		maxacc = {x = 0, y = gravity, z = 0},
		minexptime = 0.1,
		maxexptime = 1,
		minsize = min_size,
		maxsize = max_size,
		texture = texture,
		glow = glow,
	})
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

local function get_random_name(gender, tags)
	local search_tags = {gender}
	if tags then
		search_tags = { gender, unpack(tags) }
	end

	local names = npc.info.get_names(search_tags, "all_match")
	if next(names) ~= nil then
		local i = math.random(#names)
		return names[i]
	else
		-- Return a default name if no name was found
		return "Anonymous"
	end
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

function npc.assign_gender_from_texture(self)
	if is_female_texture(self.base_texture) then
		return npc.FEMALE
	else
		return npc.MALE
	end
end

local function get_random_texture(gender, age)

	local textures = npc.info.get_textures({gender, age}, "all_match")
	if next(textures) ~= nil then
		local i = math.random(#textures)
		return {textures[i]}
	else
		return {"default_"..gender..".png"}
	end

--	local textures = {}
--	local filtered_textures = {}
--	-- Find textures by gender and age
--	if age == npc.age.adult then
--		--minetest.log("Registered: "..dump(minetest.registered_entities["advanced_npc:npc"]))
--		textures = minetest.registered_entities["advanced_npc:npc"].texture_list
--	elseif age == npc.age.child then
--		textures = minetest.registered_entities["advanced_npc:npc"].child_texture
--	end
--
--	for i = 1, #textures do
--		local current_texture = textures[i][1]
--		if (gender == npc.MALE
--				and string.find(current_texture, gender)
--				and not string.find(current_texture, npc.FEMALE))
--				or (gender == npc.FEMALE
--				and string.find(current_texture, gender)) then
--			table.insert(filtered_textures, current_texture)
--		end
--	end
--
--	-- Check if filtered textures is empty
--	if filtered_textures == {} then
--		return textures[1][1]
--	end
--
--	return filtered_textures[math.random(1,#filtered_textures)]
end

--function npc.get_random_texture_from_array(age, gender, textures)
--	local filtered_textures = {}
--
--	for i = 1, #textures do
--		local current_texture = textures[i]
--		-- Filter by age
--		if (gender == npc.MALE
--				and string.find(current_texture, gender)
--				and not string.find(current_texture, npc.FEMALE)
--				and ((age == npc.age.adult
--				and not string.find(current_texture, npc.age.child))
--				or (age == npc.age.child
--				and string.find(current_texture, npc.age.child))
--		)
--		)
--				or (gender == npc.FEMALE
--				and string.find(current_texture, gender)
--				and ((age == npc.age.adult
--				and not string.find(current_texture, npc.age.child))
--				or (age == npc.age.child
--				and string.find(current_texture, npc.age.child))
--		)
--		) then
--			table.insert(filtered_textures, current_texture)
--		end
--	end
--
--	-- Check if there are no textures
--	if #filtered_textures == 0 then
--		-- Return whole array for re-evaluation
--		npc.log("DEBUG", "No textures found, returning original array")
--		return textures
--	end
--
--	return filtered_textures[math.random(1, #filtered_textures)]
--end

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
--	local number_of_items = #npc.FAVORITE_ITEMS[self.gender].phase1
--
--	for i = 1, number_of_items_to_add do
--		npc.add_item_to_inventory(
--			self,
--			npc.FAVORITE_ITEMS[self.gender].phase1[math.random(1, number_of_items)].item,
--			math.random(1,5)
--		)
--	end
	-- Add currency to the items spawned with. Will add 5-10 tier 3
	-- currency items
	local currency_item_count = math.random(5, 10)
	npc.add_item_to_inventory(self, npc.trade.prices.get_currency_itemstring("tier3"), currency_item_count)

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
function npc.initialize(entity, pos, is_lua_entity, npc_stats, npc_info)
	npc.log("INFO", "Initializing NPC at "..minetest.pos_to_string(pos))

	-- Get variables
	local ent = entity
	if not is_lua_entity then
		ent = entity:get_luaentity()
	end
	local occupation_name
	if npc_info then
		occupation_name = npc_info.occupation_name
	end

	-- Avoid NPC to be removed by mobs_redo API
	ent.remove_ok = false

	-- Flag that enables/disables right-click interaction - good for moments where NPC
	-- can't be disturbed
	ent.enable_rightclick_interaction = true

	-- Determine gender and age
	-- If there's no previous NPC data, gender and age will be randomly chosen.
	--   - Sex: Female or male will have each 50% of spawning
	--   - Age: 90% chance of spawning adults, 10% chance of spawning children.
	-- If there is previous data then:
	--   - Sex: The unbalanced gender will get a 75% chance of spawning
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
		-- Determine gender probabilities
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
		-- Get gender and age based on the probabilities
		local gender_chance = math.random(1, 100)
		local age_chance = math.random(1, 100)
		local selected_gender = ""
		local selected_age = ""
		-- Select gender
		if male_s <= gender_chance and gender_chance <= male_e then
			selected_gender = npc.MALE
		elseif female_s <= gender_chance and gender_chance <= female_e then
			selected_gender = npc.FEMALE
		end
		-- Set gender for NPC
		ent.gender = selected_gender
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
		local selected_texture = get_random_texture(selected_gender, selected_age)
		--minetest.log("Selected texture: "..dump(selected_texture))
		-- Store selected texture due to the need to restore it later
		ent.selected_texture = selected_texture
		-- Set texture and base texture
		ent.textures = {selected_texture}
		ent.base_texture = {selected_texture}
	elseif npc_info then
		-- Attempt to assign gender from npc_info
		if npc_info.gender then
		    ent.gender = npc_info.gender
		else
			local gender_chance = math.random(1,2)
			ent.gender = npc.FEMALE
			if gender_chance == 1 then
				ent.gender = npc.MALE
			end
		end
		-- Attempt to assign age from npc_info
		if npc_info.age then
			ent.age = npc_info.age
		else
			ent.age = npc.age.adult
		end
	else
		-- Randomly choose gender, and spawn as adult
		local gender_chance = math.random(1,2)
		ent.gender = npc.FEMALE
		if gender_chance == 1 then
			ent.gender = npc.MALE
		end
		ent.age = npc.age.adult
	end

	-- Initialize all gift data
	ent.gift_data = {
		-- Choose favorite items. Choose phase1 per default
		favorite_items = npc.relationships.select_random_favorite_items(ent.gender, "phase1"),
		-- Choose disliked items. Choose phase1 per default
		disliked_items = npc.relationships.select_random_disliked_items(ent.gender),
		-- Enable/disable gift item hints dialogue lines
		enable_gift_items_hints = true
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
		trade_list = {},
		-- Custom trade allows to specify more than one payment
		-- and a custom prompt (instead of the usual buy or sell prompts)
		custom_trades = {}
	}

	-- To model and control behavior of a NPC, advanced_npc follows an OS model
	-- where it allows developers to create processes. These processes executes
	-- programs, or a group of instructions that together make the NPC do something,
	-- e.g. follow a player, use a furnace, etc. The model is:
	--   - Each process has:
	--     - An `execution context`, which is memory to store variables
	--     - An `instruction queue`, which is a queue with the program instructions
	--       to execute
	--     - A `state`, whether the process is running or is paused
	--   - Processes can specify whether they allow interruptions or not. They also
	--     can opt to handle the interruption with a callback. The possible
	--     interruptions are:
	--     - Punch interruption
	--     - Rightclick interruption
	--     - Schedule interruption
	--   - Only one process can run at a time. If another process is executed,
	--     the currently running process is paused, and restored when the other ends.
	--   - Processes can be enqueued, so once the executing process finishes, the
	--     next one in the queue can be started.
	--   - One process, called the `state` process, will run by default when no
	--     processes are executing.
	ent.execution = {
        process_id = 0,
		-- Queue of processes
		process_queue = {},
		-- State process
		state_process = {},
		-- Whether state process was changed or not
		state_process_changed = false,
		-- Whether to enable process execution or not
		enable = true,
		-- Interval to run process queue scheduler
		scheduler_interval = 1,
		-- Timer for next scheduler interval
		scheduler_timer = 0,
		-- Monitor environment executes timers and registered callbacks
		monitor = {
			timer = {},
			callback = {
				to_execute = {}
			},
			enabled = true
		}
    }

    -- NPC permanent storage for data
    ent.data = {}

    -- State date
	ent.npc_state = {
		-- This table defines the types of interaction the NPC is performing
       interaction = {
           dialogues = {
               is_in_dialogue = false,
               in_dialogue_with = "",
               in_dialogue_with_name = ""
           },
		   yaw_before_interaction = 0
       },
		punch = {
			last_punch_time = 0,
		},
       movement = {
           is_idle = false,
           is_sitting = false,
           is_laying = false,
		   walking = {
			   is_walking = false,
			   path = {},
			   target_pos = {},
		   }
       },
       following = {
           is_following = false,
           following_obj = "",
           following_obj_name = ""
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
		lock = -1,
		-- Queue of programs in schedule to be enqueued
		-- Used to calculate dependencies
		dependency_queue = {},
		-- An array of schedules, meant to be one per day at some point
		-- when calendars are implemented. Allows for only 7 schedules,
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
	if occupation_name and occupation_name ~= "" and ent.age == npc.age.adult then
		-- Set occupation name
		ent.occupation_name = occupation_name
		-- Override relevant values
		npc.occupations.initialize_occupation_values(ent, occupation_name)
	end

	-- Nametag is initialized to blank
	ent.nametag = ""

	-- Set name
	if npc_info and npc_info.name then 
		if npc_info.name.value then
			ent.npc_name = npc_info.name.value
		elseif npc_info.name.tags then
			ent.npc_name = get_random_name(ent.gender, npc_info.name.tags)
		else
			ent.npc_name = get_random_name(ent.gender)
		end
	else
		ent.npc_name = get_random_name(ent.gender)
	end

	-- Set ID
	ent.npc_id = tostring(math.random(1000, 9999))..":"..ent.npc_name

	-- Generate trade offers
	npc.trade.generate_trade_offers_by_status(ent)

	-- Set initialized flag on
	ent.initialized = true
	--npc.log("WARNING", "Spawned entity: "..dump(ent))
	npc.log("INFO", "Successfully initialized NPC with name "..dump(ent.npc_name)
			..", gender: "..ent.gender..", is child: "..dump(ent.is_child)
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
	self.trader_data.trade_list = list
end

function npc.set_trading_status(self, status)
	-- Stop, if any, the casual offer regeneration timer
	npc.monitor.timer.stop(self, "advanced_npc:trade:casual_offer_regeneration")
	--minetest.log("Trader_data: "..dump(self.trader_data))
	-- Set status
	self.trader_data.trader_status = status
	-- Check if status is casual
	if status == npc.trade.CASUAL then
		-- Register timer for changing casual trade offers
		local timer_reg_success = npc.monitor.timer.register(self, "advanced_npc:trade:casual_offer_regeneration", 60,
			function(self)
				-- Re-select casual trade offers
				npc.trade.generate_trade_offers_by_status(self)
			end)
		if timer_reg_success == false then
			-- Activate timer instead
			npc.monitor.timer.start(self, "advanced_npc:trade:casual_offer_regeneration")
		end
	end

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
-- State functionality
---------------------------------------------------------------------------------------
-- All the self.npc_state variables are used to track the state of the NPC, and
-- if necessary, restore it back in case of changes. The following functions allow
-- to set different aspects of the state.
function npc.set_movement_state(self, args)
	self.npc_state.movement.is_idle = args.is_idle or false
	self.npc_state.movement.is_sitting = args.is_sitting or false
	self.npc_state.movement.is_laying = args.is_laying or false
	self.npc_state.movement.walking.is_walking = args.is_walking or false
end


---------------------------------------------------------------------------------------
-- Execution API
---------------------------------------------------------------------------------------
-- Methods for:
--  - Enqueue a program
--  - Set a program as the `state` process
--  - Execute next process in queue
--  - Pause/restore current process
--  - Process scheduling
--  - Get the current process data
--  - Create, read, write and update variables in current process
--  - Enqueue and execute instructions for the current process


-- Global namespace
npc.exec = {
	var = {},
	proc = {
		instr = {}
	}
}
-- Private namespace
local _exec = {
	proc = {}
}

-- Process states
npc.exec.proc.state = {
	INACTIVE = "inactive",
	RUNNING = "running",
	EXECUTING = "executing",
	PAUSED = "paused",
	WAITING_USER_INPUT = "waiting_user_input",
	READY = "ready"
}

npc.exec.proc.instr.state = {
	INACTIVE = "inactive",
	EXECUTING = "executing",
	INTERRUPTED = "interrupted"
}


-- This function sets the interrupt options as given from the `interrupt_options`
-- table. This table can have the following values:
--   - allow_punch, boolean
--   - allow_rightclick, boolean
--   - allow_schedule, boolean
function npc.exec.create_interrupt_options(interrupt_options)
	local interrupt_options = interrupt_options or {}
	if next(interrupt_options) ~= nil then
		local allow_punch = interrupt_options.allow_punch
		local allow_rightclick = interrupt_options.allow_rightclick
		local allow_schedule = interrupt_options.allow_schedule

		-- Set defaults
		if allow_punch == nil then allow_punch = true end
		if allow_rightclick == nil then allow_rightclick = true end
		if allow_schedule == nil then allow_schedule = true end

		return {
			allow_punch = allow_punch,
			allow_rightclick = allow_rightclick,
			allow_schedule = allow_schedule
		}
	else
		return {
			allow_punch = true,
			allow_rightclick = true,
			allow_schedule = true
		}
	end
end

function _exec.get_new_process_id(self)
    self.execution.process_id = self.execution.process_id + 1
    if self.execution.process_id > 10000 then
        self.execution.process_id = 0
    end
    return self.execution.process_id
end

function _exec.create_process_entry(program_name, arguments, interrupt_options, is_state_program, process_id)
	return {
        id = process_id,
		program_name = program_name,
		arguments = arguments,
		state = npc.exec.proc.state.INACTIVE,
		execution_context = {
			data = {},
			instr_interval = 1,
			instr_timer = 0
		},
		instruction_queue = {},
		current_instruction = {
			entry = {},
			state = npc.exec.proc.instr.state.INACTIVE,
			pos = {}
		},
		interrupt_options = npc.exec.create_interrupt_options(interrupt_options),
		interrupted_process = {},
		is_state_process = is_state_program
	}
end

-- This function creates a process for the given program, and
-- places it into the process queue.
function npc.exec.enqueue_program(self, program_name, arguments, interrupt_options, is_state_program)
	if is_state_program == nil then
		is_state_program = false
	end
	if is_state_program == true then
		npc.exec.set_state_program(self, program_name, arguments, interrupt_options)
		-- Enqueue state process
		self.execution.process_queue[#self.execution.process_queue + 1] = self.execution.state_process
	else
		-- Enqueue process
		self.execution.process_queue[#self.execution.process_queue + 1] =
			_exec.create_process_entry(program_name, arguments, interrupt_options, is_state_program, _exec.get_new_process_id(self))
	end
end

-- This function creates a state process. The state process will execute
-- everytime there's no other process executing
function npc.exec.set_state_program(self, program_name, arguments, interrupt_options)
	-- Disable monitor - give a chance to this state process to do what it has to do
	self.execution.monitor.enabled = false
	-- This flag signals the state process was changed and scheduler needs to consume
	self.execution.state_process_changed = true
	self.execution.state_process = {
		program_name = program_name,
		arguments = arguments,
		state = npc.exec.proc.state.INACTIVE,
		execution_context = {
			data = {},
			instr_interval = 1,
			instr_timer = 0
		},
		instruction_queue = {},
		current_instruction = {
			entry = {},
			state = npc.exec.proc.instr.state.INACTIVE,
			pos = {}
		},
		interrupt_options = npc.exec.create_interrupt_options(interrupt_options),
		is_state_process = true,
		state_process_id = os.time()
	}
end

-- Convenience function that returns first process in the queue
function npc.exec.get_current_process(self)
	local result = self.execution.process_queue[1]
	if result then
		if next(result) == 0 then
			return nil
		end
	end
	return result
end


-- This function always execute the process at the start of the process
-- queue. When a process is stopped (because its instruction queue is empty
-- or because the process itself stops), the entry is removed from the
-- process queue, and thus the next process to execute will be the first one
-- in the queue.

function npc.exec.execute_process(self)
	local current_process = self.execution.process_queue[1]
	-- Execute current process
	if current_process then
		-- Restore scheduler interval
		self.execution.scheduler_interval = 1
		if not current_process.is_state_process then
			npc.log("EXECUTION", "NPC "..dump(self.npc_name).." is executing: "..dump(current_process.program_name))
		end
        current_process.state = npc.exec.proc.state.EXECUTING
		npc.programs.execute(self, current_process.program_name, current_process.arguments)
        current_process.state = npc.exec.proc.state.RUNNING
		-- Re-enable monitor
		if current_process.is_state_process then
			self.execution.monitor.enabled = true
		end
	end
end


---------------------------------------------------------------------------------------
-- Interruption algorithm
---------------------------------------------------------------------------------------
-- Interruption of an executing process can come from three sources:
--   - NPC is left-clicked (or punch)
--   - NPC is right-clicked (or rightclick)
--   - Job scheduler has identified it is time to start a process
-- When an interrupt happens, and another process needs to be executed, the
-- workflow should be the following:
--   1. Enqueue the new process to be scheduled. 
--      a. If for some reason the process queue *has more than one* process,
--         then the process will have to be enqueued with high priority,
--         meaning next to the current process.
--   2. Pause the current executing process using `npc.exec.pause_process(self)`
--      The new process will be executed by `npc.exec.pause_process()`.
--   3. The process finishes execution successfully, in which the scheduler
--      will notice that and restore the interrupted process properly
--
-- It is very important that a process is enqueued before pausing the current
-- process. The pause will not work itself if that condition is not met

-- This function enqueues an array of processes right after the current process
-- Each element in `program_entries` is a Lua table with three parameters:
--   - program_name
--   - arguments
--   - interrupt_options
function _exec.priority_enqueue(self, program_entries)
--	minetest.log("BEGIN PRIORITY ENQUEUE")
--	minetest.log("Initial queue: "..dump(self.execution.process_queue))
	-- Check if the queue has more than one (current) process
	if #self.execution.process_queue > 1 then
		npc.log("EXECUTION", "More than One: "..dump(#self.execution.process_queue))
		-- Get current process entry
		--local current_process = self.execution.process_queue[1]
		-- Backup the current process queue
--		local backup_queue = self.execution.process_queue
--		minetest.log("Backup queue size: "..dump(#backup_queue))
--		-- Remove current process from backup_queue
--		table.remove(backup_queue, 1)
--		minetest.log("Backup queue size after dequeue: "..dump(#backup_queue))
--		-- Recreate queue, re-enqueue first process
--		minetest.log("ENqueue")
--		self.execution.process_queue[#self.execution.process_queue + 1] = current_process
		npc.log("EXECUTION", "Queue size after enqueue: "..dump(#self.execution.process_queue))
		-- Enqueue the next processes with high priority (next to the current)
		npc.log("EXECUTION", "Enqueue all new")
		for i = 1, #program_entries do
			if program_entries[i].is_state_program == true then
				npc.exec.set_state_program(self,
					program_entries[i].program_name,
					program_entries[i].arguments,
					program_entries[i].interrupt_options)
				-- Enqueue state process
				table.insert(self.execution.process_queue, i + 1, self.execution.state_process)
			else
				-- Enqueue normal process
				table.insert(
					self.execution.process_queue, i + 1, _exec.create_process_entry(
						program_entries[i].program_name,
						program_entries[i].arguments,
						program_entries[i].interrupt_options,
						program_entries[i].is_state_program,
						_exec.get_new_process_id(self)))
			end
		end
		--minetest.log("Backup queue after all new: "..dump(#backup_queue))
	else
		npc.log("EXECUTION", "Only one process in queue")
		-- There is only one process, therefore just enqueue every process
		for i = 1, #program_entries do
			if program_entries[i].is_state_program == true then
				npc.exec.set_state_program(self,
					program_entries[i].program_name,
					program_entries[i].arguments,
					program_entries[i].interrupt_options)
				-- Enqueue state process
				self.execution.process_queue[#self.execution.process_queue + 1] = self.execution.state_process
			else
				-- Enqueue normal process
				self.execution.process_queue[#self.execution.process_queue + 1] = _exec.create_process_entry(
					program_entries[i].program_name,
					program_entries[i].arguments,
					program_entries[i].interrupt_options,
					program_entries[i].is_state_program,
					_exec.get_new_process_id(self))
			end
		end
	end
end

-- This function handles a new process called by an interrupt.
-- Will execute steps 1 and 2 of the above algorithm. The scheduler 
-- will take care of handling step 3.
function npc.exec.interrupt(self, new_program, new_arguments, interrupt_options)
	-- Enqueue process with priority
	_exec.priority_enqueue(self,
		{[1] = {program_name=new_program, arguments=new_arguments, interrupt_options=interrupt_options}})
	--minetest.log("Pause")
	minetest.log("Interrupted process: "..dump(self.execution.process_queue[1]))
	-- Check process - if the instruction queue is empty, do not store
	-- Pause current process
	_exec.pause_process(self)

	local interrupted_process = self.execution.process_queue[1]
	-- Dequeue process
	table.remove(self.execution.process_queue, 1)

	-- Find if interrupted process has more instructions to execute
	local has_more_instructions = next(interrupted_process.instruction_queue) ~= nil
	--minetest.log("Process has more instructions: "..dump())
	if has_more_instructions then
		-- Store interrupted process
		local current_process = self.execution.process_queue[1]
		current_process.interrupted_process = interrupted_process
	end
	-- Restore process scheduler interval
	self.execution.scheduler_interval = 1
	--minetest.log("Execute")
	-- Execute current process
	npc.exec.execute_process(self)
end

-- This function pauses a process and sets its state as waiting for user input.
-- The process scheduler and instruction executer will skip any process in this state.
-- Once the process is ready to run again, the `npc.exec.set_ready_state()` function
-- should be called, and execution will continue.
function npc.exec.set_input_wait_state(self)
	npc.log("EXECUTION", "Setting input wait...")
	if self.execution.process_queue[1] then
		-- Call pause to do the instruction interruption
		_exec.pause_process(self)
		-- Change process state
		self.execution.process_queue[1].state = npc.exec.proc.state.WAITING_USER_INPUT
	end
end

function npc.exec.set_ready_state(self)
	if self.execution.process_queue[1] then
		-- Change process state
		self.execution.process_queue[1].state = npc.exec.proc.state.READY
	end
end

-- If there is another process in the queue, this function pauses a 
-- currently executing process, then executes the 
function _exec.pause_process(self, set_instruction_as_interrupted)
	if #self.execution.process_queue == 1 then
		npc.log("WARNING", "Unable to pause current process without anoher process in queue.\nCurrent queue: "
			..dump(self.execution.process_queue))
		return
	end

	local current_process = self.execution.process_queue[1]
	if current_process then
		-- Check if there are instructions in the instruction queue
		if next(current_process.instruction_queue) ~= nil then
			-- If the instruction is interrupt, then dequeue that instruction :)
			if current_process.instruction_queue[1].name == "advanced_npc:interrupt" then
				-- Dequeue instruction
				table.remove(current_process.instruction_queue, 1)
				-- Check if there are more instructions
				if next(current_process.instruction_queue) ~= nil then
					-- Set entry
					current_process.current_instruction.entry = current_process.instruction_queue[1]
					-- Set state
					current_process.current_instruction.state = npc.exec.proc.instr.state.INTERRUPTED
				else
					-- Set entry to blank as there is no other instruction
					current_process.current_instruction.entry = {}
					-- Set state
					current_process.current_instruction.state = npc.exec.proc.instr.state.INACTIVE
				end
			else
				-- Check current instruction
				if current_process.current_instruction.entry
						and current_process.current_instruction.state == npc.exec.proc.instr.state.EXECUTING then
						-- This condition shouldn't become true
						--and set_instruction_as_interrupted == true then
					-- Change instruction state
					current_process.current_instruction.state = npc.exec.proc.instr.state.INTERRUPTED
					-- The following flow has been commented out as it doesn't gets executed.
					--elseif set_instruction_as_interrupted == nil or set_instruction_as_interrupted == false then
					--	current_process.current_instruction.state = npc.exec.proc.instr.state.INACTIVE
				end
			end
		end
		--minetest.log("Process after pausing: "..dump(current_process))
		-- Change process state
		current_process.state = npc.exec.proc.state.PAUSED
	end
end

-- This function restores the process that was running before the
-- current one (the interrupted process).
-- As it can only be runned with the interrupted process being enqueued
-- before calling this function, this function is private and only
-- used by the scheduler (which will enqueue the interrupted process before
-- calling this)
function _exec.restore_process(self)
	local current_process = self.execution.process_queue[1]
	if current_process then
		minetest.log("Restoring process: "..dump(current_process.program_name))
		-- Change process state
		current_process.state = npc.exec.proc.state.RUNNING
		-- Check if any instruction was interrupted
		if current_process.current_instruction.entry
			and current_process.current_instruction.state == npc.exec.proc.instr.state.INTERRUPTED then
			-- TODO: Do we really want to restore position?
			-- Restore position
			--self.object:setpos(current_process.current_instruction.pos)
			-- Execute instruction
			minetest.log("Re-executing instruction: "..dump(current_process.current_instruction.entry.name))
			_exec.proc.execute(self, current_process.current_instruction.entry)
		end
	end
end

---------------------------------------------------------------------------------------
-- Scheduler algorithm
---------------------------------------------------------------------------------------
-- This function will manage how processes are executed. This function needs
-- to be called on a one second interval. The function will check:
--   - If the process queue is emtpy and there is a state process, enqueue the
--     the state process and execute
--   - If the current process' instruction queue is empty:
--     - If the process is a `state` process, and no other process is in queue,
--       re-execute `state` process.
--     - If the process is a `state` process and there is a process in queue,
--       - Remove current process from queue
-- 		 - Store the current process entry into the `interrupted_process` field of
--         the next process in queue.
--       - Execute next process in queue
--     - If the process is *not* a `state` process and there is a process entry in
--       the `interrupted_process` field:
--       - Remove current process from queue
--       - Enqueue the entry in the `interrupted_process` field
--       - Execute next process in the queue
--   - If the instruction queue is not empty, continue
function npc.exec.process_scheduler(self)
	npc.log("EXECUTION", "Current process queue size: "..dump(#self.execution.process_queue))
	-- minetest.log("Queue for "..dump(self.npc_name))
	-- for i = 1, #self.execution.process_queue do
	-- 	minetest.log("["..dump(self.execution.process_queue[i].program_name).."]")
	-- end
	-- Check current process
	local current_process = self.execution.process_queue[1]
	if current_process then
		-- Check current process state
		if current_process.state == npc.exec.proc.state.EXECUTING then
			-- Do not interrupt process while the process is enqueuing instructions
			return
		elseif current_process.state == npc.exec.proc.state.INACTIVE then
			-- Execute process
			npc.exec.execute_process(self)
		elseif current_process.state == npc.exec.proc.state.READY then
			-- Change state to running
			current_process.state = npc.exec.proc.state.RUNNING
		elseif current_process.state == npc.exec.proc.state.PAUSED then
			-- Restore process
			_exec.restore_process(self)
		end
		-- Check if instruction queue is empty
		if current_process.instruction_queue and #current_process.instruction_queue == 0
				and current_process.state == npc.exec.proc.state.RUNNING then
			-- Check if this is a state process
			if current_process.is_state_process == true then
				-- Check if the process queue only has this process
				if #self.execution.process_queue == 1 then
					-- Check if state process was changed
					if self.execution.state_process_changed == true then
						npc.log("EXECUTION", "Switching from state process "
								..dump(self.execution.process_queue[1].program_name)
								.." to "
								..dump(self.execution.state_process.program_name))
						-- Dequeue this process, enqueue new one
						self.execution.process_queue[1] = self.execution.state_process
						-- Change flag back
						self.execution.state_process_changed = false
					end
					-- Since this is a state process, re-execute
					npc.log("EXECUTION", "Hi, executing state process "..dump(self.execution.process_queue[1].program_name))
					npc.exec.execute_process(self)
				else
					-- Changed state process check - an old state process could be enqueued,
					-- but the state process was changed. If this is is true, ignore old
					-- entry in the process queue.
					local next_enqueued_process = self.execution.process_queue[2]
					if self.execution.state_process_changed == true
						and next_enqueued_process.id ~= current_process.id
							and next_enqueued_process.is_state_process == true then
						-- Assume every enqueued state process is old and discard
						table.remove(self.execution.process_queue, 2)
						-- Change flag back
						self.execution.state_process_changed = false
					else
						-- Next process is not a state process, interrupt current state process
						npc.log("EXECUTION", "Current process queue size: "..dump(#self.execution.process_queue))
						-- Pause current process
						current_process.state = npc.exec.proc.state.PAUSED
						-- Dequeue process
						table.remove(self.execution.process_queue, 1)
						-- Get next process in queue
						local next_process = self.execution.process_queue[1]
						-- Store the interrupted process in the next process
						next_process.interrupted_process = current_process
					end
					-- Execute next process
					npc.exec.execute_process(self)
				end
			else
				npc.log("EXECUTION", "Current process name: "..dump(current_process.program_name))
				npc.log("EXECUTION", "Process queue size: "..dump(#self.execution.process_queue))
				npc.log("EXECUTION", "Current instrcution queue size: "..dump(#current_process.instruction_queue))
				npc.log("EXECUTION", "Current process state: "..dump(current_process.state))
				-- This is not a state process, check the interrupted process field
				if next(current_process.interrupted_process) ~= nil then
					npc.log("EXECUTION", "There is an interrupted process: "..dump(current_process.interrupted_process.program_name))
					npc.log("EXECUTION", "------------------------------")
					npc.log("EXECUTION", "Is state process? "..dump(current_process.interrupted_process.is_state_process))
					npc.log("EXECUTION", "State process ID: "..dump(current_process.interrupted_process.state_process_id))
					npc.log("EXECUTION", "Valid state process ID: "..dump(self.execution.state_process.state_process_id))

					if current_process.interrupted_process.is_state_process == true 
						and current_process.interrupted_process.state_process_id 
						and (current_process.interrupted_process.state_process_id < self.execution.state_process.state_process_id) then
						-- Do nothing, just dequeue process
						npc.log("EXECUTION", "Found an old state process that was interrupted.\n"
								..dump(current_process.interrupted_process.program_name).." WILL NOT be re-enqueued")
						npc.log("EXECUTION", "Process "..dump(self.execution.process_queue[1].program_name)
								.." is finished execution and will be dequeued")
						-- Dequeue process
						table.remove(self.execution.process_queue, 1)
						-- Check if there are more processes
						if #self.execution.process_queue > 0 then
							-- Execute new process
							npc.exec.execute_process(self)
						end
						return
					end

					-- Dequeue process
					table.remove(self.execution.process_queue, 1)
					-- Re-enqueue the interrupted process
					self.execution.process_queue[#self.execution.process_queue + 1] = current_process.interrupted_process
					if #self.execution.process_queue > 1 then
						-- Execute next process in queue
						npc.exec.execute_process(self)
					else
						-- Execute next process in queue which is interrupted
						_exec.restore_process(self)
					end
				else
					npc.log("EXECUTION", "Process "..dump(self.execution.process_queue[1].program_name).." is finished execution")
					-- Dequeue process
					table.remove(self.execution.process_queue, 1)
					-- Check if there are more processes
					if #self.execution.process_queue > 0 then
						-- Execute new process
						npc.exec.execute_process(self)
					end
				end
			end
		end
	else
		-- Process queue is empty, enqueue state process if it is defined
		if next(self.execution.state_process) ~= nil then
			npc.log("EXECUTION", "NPC "..dump(self.npc_name).." is executing: "..dump(self.execution.state_process.program_name))
			self.execution.process_queue[#self.execution.process_queue + 1] = self.execution.state_process
			-- Execute state process
			npc.exec.execute_process(self)
		end
	end
end

---------------------------------------------------------------------------------------
-- Process instructions functionality - enqueue and execute instructions
-- for the currently executing process
---------------------------------------------------------------------------------------
-- This function enqueues a given instruction with its arguments
-- in the current process' instruction queue. If var_name is given,
-- results of this function are stored in the execution context with that
-- var_key
function npc.exec.proc.enqueue(self, name, args, var_name)
	local current_process = self.execution.process_queue[1]
	if current_process then
		current_process.instruction_queue[#current_process.instruction_queue + 1] =
			{name=name, args=args, var_name=var_name}
	end
end

-- Private function to execute a given instruction entry
function _exec.proc.execute(self, entry)
	if entry ~= nil and next(entry) ~= nil then
		local current_process = self.execution.process_queue[1]
		if current_process then
			-- Set current instruction params
			current_process.current_instruction.entry = entry
			current_process.current_instruction.pos = self.object:getpos()
			current_process.current_instruction.state = npc.exec.proc.instr.state.EXECUTING
			-- Execute current instruction
			npc.log("EXECUTION", "Executing instruction: "..dump(entry.name))
			local result = npc.programs.instr.execute(self, entry.name, entry.args)
			if entry.name == "advanced_npc:interrupt" then
				-- Do not do anything else, the interrupt instruction was already
				-- dequeued.
				return
			end
			-- Check if var_name was given
			if entry.var_name then
				if npc.exec.var.get(self, entry.var_name) then
					-- Update the value
					npc.exec.var.set(self, entry.var_name, result)
				else
					-- Create new var with value
					npc.exec.var.put(self, entry.var_name, result, false)
				end
			end
			-- Dequeue from instruction queue
			table.remove(current_process.instruction_queue, 1)
		end
	end
--	minetest.log("END PRIVATE PROC EXEC")
end

-- This function executes the next instruction entry in the current
-- process' instruction queue
function npc.exec.proc.execute(self)
	--minetest.log("PROCESS EXECUTE BEGIN")
	local current_process = self.execution.process_queue[1]
	if current_process then
		-- Get next instruction entry in queue
		local entry = current_process.instruction_queue[1]
		-- Execute instruction
		_exec.proc.execute(self, entry)
	end
	--minetest.log("PROCESS EXECUTE END")
end

---------------------------------------------------------------------------------------
-- Execution routine
---------------------------------------------------------------------------------------
-- This function is to be executed on each step() of the Lua entity
-- Algorithm:
--   1. Increase the timer with dtime
--   2. If the timer has reached the interval, then:
--      a. Reset the timer and execute `npc.exec.process_scheduler(self)`
--   3. Increase the current process' instruction timer with dtime
--   4. If the instruction timer has reached the interval, then:
--      a. Reset the instruction timer and execute `noc.exec.proc.execute(self)`
function npc.exec.execution_routine(self, dtime)
	local execution = self.execution
	-- Increase process scheduler timer
	execution.scheduler_timer = execution.scheduler_timer + dtime
	-- Check if timer reached interval
	if execution.scheduler_timer >= execution.scheduler_interval then
		-- Reset timer
		execution.scheduler_timer = 0
		npc.log("EXECUTION", "Executing scheduler for NPC "..dump(self.npc_name))
		-- Execute process scheduler
		npc.exec.process_scheduler(self)
	end
	-- Get current process
	local current_process = execution.process_queue[1]
	if current_process ~= nil and current_process.execution_context ~= nil then
		--minetest.log("STATE: "..dump(self.execution.process_queue[1].state))
		--minetest.log("PROCESS: "..dump(self.execution.process_queue[1]))
		if current_process.state == npc.exec.proc.state.RUNNING then
			-- Increase timer
			current_process.execution_context.instr_timer =
				current_process.execution_context.instr_timer + dtime
			-- Check if timer reached interval
			if current_process.execution_context.instr_timer
					>= current_process.execution_context.instr_interval then
				-- Reset timer
				--minetest.log("HI, RESET")
				current_process.execution_context.instr_timer = 0
				-- Check if NPC is walking
				if self.npc_state.movement.walking.is_walking == true then
					-- Move NPC to expected position to ensure not getting lost
					local pos = self.npc_state.movement.walking.target_pos
					if vector.distance(self.object:getpos(), pos) > 0.2 then
						npc.log("INFO", "Corrected position for walking NPC "..dump(self.npc_name).." to "..minetest.pos_to_string(pos))
						self.object:moveto({x=pos.x, y=pos.y, z=pos.z})
					end
				end
				-- Execute next instruction in process' queue
				npc.exec.proc.execute(self)
			end
		end
	end
end

---------------------------------------------------------------------------------------
-- Variable functionality - create, read, update and delete variables in the
-- current process.
-- IMPORTANT: These variables are deleted when the process is finished execution.
--            For permanent storage, use npc.data.* functions.
---------------------------------------------------------------------------------------
-- This function adds a value to the execution context of the
-- current process.
-- Readonly defaults to false. Returns false if failed due to
-- key-name conflict, or returns true if successful
function npc.exec.var.put(self, name, value, readonly)
	-- Retrieve current process execution context
	local current_process = self.execution.process_queue[1]
	if current_process then
		local context = current_process.execution_context
		-- Check if variable exists
		if context[name] ~= nil then
			npc.log("ERROR", "Attempt to create new variable with name "..name.." failed"..
				"due to variable already existing: "..dump(context[name]))
			return false
		end
		context[name] = {value = value, readonly = readonly}
		return true		
	end
end

-- Returns the value of a given key. If not found returns nil.
function npc.exec.var.get(self, name)
	-- Retrieve current process execution context
	local current_process = self.execution.process_queue[1]
	if current_process then
		local context = current_process.execution_context
		local result = context[name]
		if result == nil then
			return nil
		else
			return result.value
		end
	end
end

function npc.exec.var.get_or_put_if_nil(self, name, initial_value)
	local var = npc.exec.var.get(self, name)
	if var == nil then
		npc.exec.var.put(self, name, initial_value)
		return initial_value
	else
		return var
	end
end

-- This function updates a value in the execution context.
-- Returns false if the value is read-only or if key isn't found.
-- Returns true if able to update value
function npc.exec.var.set(self, name, new_value)
    -- Retrieve current process execution context
	local current_process = self.execution.process_queue[1]
	if current_process then
		local context = current_process.execution_context
		local var = context[name]
		if var == nil then
			return false
		else
			if var.readonly == true then
				npc.log("ERROR", "Attempt to set value of readonly variable: "..name)
				return false
			end
			var.value = new_value
		end
		return true
	end
end

-- This function removes a variable from the execution context.
-- If the key doesn't exist, returns nil, otherwise, returns
-- the value removed.
function npc.exec.var.remove(self, name)
    -- Retrieve current process execution context
	local current_process = self.execution.process_queue[1]
	if current_process then
		local context = current_process.execution_context
		local result = context[name]
		if result == nil then
			return nil
		else
			-- Clear variable
			npc.exec.get_current_process(self).execution_context[name] = nil
			return result
		end
	end
end

---------------------------------------------------------------------------------------
-- Permanent storage functionality - create, read, update and delete variables
-- in the NPC's permnanent storage.
-- IMPORTANT: These variables are *NOT* deleted. Be careful what you store on it or
--            the NPC object can grow in size very quickly.
--            For temporary storage, use npc.exec.var.* functions.
---------------------------------------------------------------------------------------
-- Namespace
npc.data = {}

-- This function adds a value to the execution context of the
-- current process.
-- Readonly defaults to false. Returns false if failed due to
-- key-name conflict, or returns true if successful
function npc.data.put(self, name, value, readonly)
    -- Check if variable exists
    if self.data[name] ~= nil then
        npc.log("ERROR", "Attempt to create new variable with name "..name.." failed"..
                "due to variable already existing: "..dump(self.data[name]))
        return false
    end
    self.data[name] = {value = value, readonly = readonly}
    return true
end

-- Returns the value of a given key. If not found returns nil.
function npc.data.get(self, name)
    local result = self.data[name]
    if result == nil then
        return nil
    else
        return result.value
    end
end

-- Convenience function for initializing a variable if nil
function npc.data.get_or_put_if_nil(self, name, initial_value)
	local var = npc.data.get(self, name)
	if var == nil then
		npc.data.put(self, name, initial_value, false)
		return initial_value
	else
		return var
	end
end

-- This function updates a value in the execution context.
-- Returns false if the value is read-only or if key isn't found.
-- Returns true if able to update value
function npc.data.set(self, name, new_value)
    local var = self.data[name]
    if var == nil then
        return false
    else
        if var.readonly == true then
            npc.log("ERROR", "Attempt to set value of readonly variable: "..name)
            return false
        end
        var.value = new_value
    end
    return true
end

-- This function removes a variable from the execution context.
-- If the key doesn't exist, returns nil, otherwise, returns
-- the value removed.
function npc.data.remove(self, name)
    local result = self.data[name]
    if result == nil then
        return nil
    else
        -- Clear variable
        self.data[name] = nil
        return result
    end
end

---------------------------------------------------------------------------------------
-- Monitor API: API that executes timers and registered callbacks.
--   - Timers can be registered by programs or by code in general, and can
--     have a callback which is executed when the timer reaches the interval.
--   - Callbacks are for programs, instructions and for interrupts (punch, right-click,
--     and scheduled entries). The callback is executed after a program,
--     instruction or interrupt is executed.
-- IMPORTANT: Please, keep *all your callbacks* as light as possible. While useful,
--            too many timers or callbacks can deteriorate performance, as all could
--			  run on NPC steps.
---------------------------------------------------------------------------------------
-- Namespace
npc.monitor = {
	timer = {
		registered = {}
	},
	callback = {
		registered = {},
		-- Constant values
		type = {
			program = "program",
			instruction = "instruction",
			interaction = "interaction",
		},
		subtype = {
			on_punch = "on_punch",
			on_rightclick = "on_rightclick",
			on_schedule = "on_schedule",
		}
	}
}

-- Register a timer. The timer can have the following arguments:
--   - name: unique identifier for timer
--   - interval: when timer reaches this value, callback will be executed
--   - callback: function to be executed when timer reaches interval
--   - initial_value: default is 0. Give this to start with a specific value
function npc.monitor.timer.register(name, interval, callback)
	if npc.monitor.timer.registered[name] ~= nil then
		npc.log("DEBUG", "Attempt to register an existing timer: "..dump(name))
		return false
	else
		local timer = {
			interval = interval,
			callback = callback
		}
		npc.monitor.timer.registered[name] = timer
	end
	return true
end

function npc.monitor.timer.start(self, name, interval, args)
	if self.execution.monitor.timer[name] then
		npc.log("DEBUG", "Attempted to start already started timer: "..dump(name))
		return
	end
	local timer = npc.monitor.timer.registered[name]
	if timer then
		-- Activate timer by moving it into the active timer array
		self.execution.monitor.timer[name] = {
			value = 0,
			interval = interval or timer.interval,
			args = args
		}
	else
		npc.log("DEBUG", "Attempted to start non-existent timer: "..dump(name))
	end
end

function npc.monitor.timer.stop(self, name)
	if self.execution.monitor.timer[name] == nil then
		npc.log("DEBUG", "Attempted to stop already stopped timer: "..dump(name))
		return
	end
	local timer = self.execution.monitor.timer[name]
	if timer then
		-- Set timer for removal on next monitor execution routine
		self.execution.monitor.timer[name].remove = true
	else
		npc.log("DEBUG", "Attempted to stop non-existent timer: "..dump(name))
	end
end

-- Name is the name of function for which callback is being registered.
-- Use program or instruction name for corresponding programs or instructions,
-- and "on_punch", "on_rightclick", "on_activate", "on_schedule" for interrupts
function npc.monitor.callback.register(name, type, subtype, callback)
	-- Initialize type and subtype if they don't exist
	if npc.monitor.callback.registered[type] == nil then
		npc.monitor.callback.registered[type] = {}
	end
	if npc.monitor.callback.registered[type][subtype] == nil then
		npc.monitor.callback.registered[type][subtype] = {}
	end
	-- Check if callback already exists
	if npc.monitor.callback.registered[type][subtype][name] ~= nil then
		npc.log("DEBUG", "Attempt to register an existing callback: "..dump(name))
		return
	else
		-- Register callback
		npc.monitor.callback.registered[type][subtype][name] = callback
	end
end

function npc.monitor.callback.exists(type, subtype)
	if npc.monitor.callback.registered[type] ~= nil then
		if npc.monitor.callback.registered[type][subtype] ~= nil then
			return next(npc.monitor.callback.registered[type][subtype]) ~= nil
		end
	end
	return false
end

function npc.monitor.callback.enqueue(self, type, subtype, name)
	self.execution.monitor.callback.to_execute[#self.execution.monitor.callback.to_execute + 1] = {
		name = name,
		type = type,
		subtype = subtype
	}
end

function npc.monitor.callback.enqueue_all(self, type, subtype)
	for name,_ in pairs(npc.monitor.callback.registered[type][subtype]) do
		self.execution.monitor.callback.to_execute[#self.execution.monitor.callback.to_execute + 1] = {
			name = name,
			type = type,
			subtype = subtype
		}
	end
end

function npc.monitor.execution_routine(self, dtime)
	if self.execution.monitor.enabled == false then
		return
	end
	-- Execute timers - traverse the array of active timers and increase
	-- their respective values
	for name,timer in pairs(self.execution.monitor.timer) do
		if timer.remove == true then
			self.execution.monitor.timer[name] = nil
		else
			-- Increase value
			timer.value = timer.value + dtime
			-- Check if interval is met
			if timer.value >= timer.interval then
				-- Reset value
				timer.value = 0
				-- Execute callback
				npc.monitor.timer.registered[name].callback(self, timer.args)
			end
		end
	end
	-- Execute callbacks - traverse array of callbacks to execute
	for i = #self.execution.monitor.callback.to_execute, 1, -1 do
		local callback = self.execution.monitor.callback.to_execute[i]
		-- Execute callback
		npc.monitor.callback.registered[callback.type][callback.subtype][callback.name](self)
		-- Remove callback from the execute array
		self.execution.monitor.callback.to_execute[i] = nil
	end
end


---------------------------------------------------------------------------------------
-- Schedule functionality
---------------------------------------------------------------------------------------
-- Schedules allow the NPC to do different things depending on the time of the day.
-- The time of the day is in 24 hours and is consistent with the Minetest
-- /time command. Hours will be written as numbers: 1 for 1:00, 13 for 13:00 or 1:00 PM
-- The API is as following: a schedule can be created for a specific date or for a
-- day of the week. A date is a string in the format MM:DD
npc.schedule = {
	const = {
		types = {
			generic = "generic",
			date_based = "date_based"
		}
	},
	entry = {}
}

npc.schedule_properties = {
	put_item = "put_item",
	put_multiple_items = "put_multiple_items",
	take_item = "take_item",
	trader_status = "trader_status",
	can_receive_gifts = "can_receive_gifts",
	flag = "flag",
	enable_gift_items_hints = "enable_gift_items_hints",
	set_trade_list = "set_trade_list"
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
function npc.schedule.create(self, schedule_type, date)
	if schedule_type == npc.schedule.const.types.generic then
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
	elseif schedule_type == npc.schedule.const.types.date then
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

function npc.schedule.delete(self, schedule_type, date)
	-- Delete schedule by setting entry to nil
	self.schedules[schedule_type][date] = nil
end

-- Schedule entries API
-- Allows to add, get, update and delete entries from each
-- schedule. Attempts to be as safe-fail as possible to avoid crashes.

-- Actions is an array of actions and tasks that the NPC
-- will perform at the scheduled time on the scheduled date
function npc.schedule.entry.put(self, schedule_type, date, time, check, actions)
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

function npc.schedule.entry.get(self, schedule_type, date, time)
	-- Check if schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Return schedule
		return self.schedules[schedule_type][date][time]
	else
		-- Schedule for date not found
		return nil
	end
end

function npc.schedule.entry.set(self, schedule_type, date, time, check, actions)
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

function npc.schedule.entry.remove(self, schedule_type, date, time)
	-- Check schedule for date exists
	if self.schedules[schedule_type][date] ~= nil then
		-- Remove schedule entry by setting to nil
		self.schedules[schedule_type][date][time] = nil
	else
		-- Schedule not found for date
		return nil
	end
end

-- Execution routine for schedules
-- For now, only one program per hour should be created by schedule
function npc.schedule.execution_routine(self, dtime)

	if self.schedules.enabled == true then
		-- Get time of day
		local time = get_time_in_hours()
		-- Check if time is an hour
		if ((time % 1) < dtime) then
			-- Get integer part of time
			time = (time) - (time % 1)
			if not(time > self.schedules.lock or (time == 0 and self.schedules.lock == 23)) then
				return
			end
			npc.log("INFO", "Time: "..dump(time))
			-- Activate lock to avoid more than one entry to this code
			self.schedules.lock = time
			-- Check if there is a schedule entry for this time
			-- Note: Currently only one schedule is supported, for day 0
			local schedule = self.schedules.generic[0]
			if schedule ~= nil then
				-- Check if schedule for this time exists
				if schedule[time] ~= nil then
					-- Check if schedules are enabled, and interruptions by scheduler allowed by
					-- current state/executing script
					local current_process = self.execution.process_queue[1]
					--minetest.log("CURRENT PROCESS name: "..dump(current_process.program_name))
					if current_process and current_process.interrupt_options.allow_scheduler == false then
						-- Don't check schedules any further
						return
					end
					-- Hold the programs to be enqueued
					local programs_to_enqueue = {}
					local entries_to_enqueue = {}
					-- Check if a program should be enqueued or not
					for i = 1, #schedule[time] do
						-- Check chance
						local execution_chance = math.random(1, 100)
						if not schedule[time][i].chance or
								(schedule[time][i].chance and execution_chance <= schedule[time][i].chance) then
							-- Check if entry has dependency on other entry
							local dependencies_met
							if schedule[time][i].depends then
								-- TODO: Fix dependency check issue
								-- minetest.log("Programs to enqueue size: "..dump(programs_to_enqueue))
								-- minetest.log("i: "..dump(i))
								-- minetest.log("Dependency: "..dump(schedule[time][i].depends[1]))
								-- minetest.log("programs to enqueue[1]: "..dump(programs_to_enqueue[1]))
								-- for key,var in pairs(programs_to_enqueue) do
								-- 	minetest.log("Key: "..dump(key))
								-- end
								-- minetest.log("entries to enqueue[i]: "..dump(entries_to_enqueue[schedule[time][i].depends[1]]))
								if entries_to_enqueue[schedule[time][i].depends[1]] ~= nil then
									dependencies_met = true
								else
									dependencies_met = false
								end
							end

							-- minetest.log("Dependencies met for entry with name: "..dump(schedule[time][i].program_name)..": "..dump(dependencies_met))

							-- Check for dependencies being met
							if dependencies_met == nil or dependencies_met == true then
								programs_to_enqueue[#programs_to_enqueue + 1] = schedule[time][i]
								entries_to_enqueue[i] = i
							else
								npc.log("DEBUG", "Skipping schedule entry for time "..dump(time)..": "..dump(schedule[time][i]))
							end
						end
					end
					-- Enqueue all programs in programs_to_enqueue
					if #programs_to_enqueue > 0 then
						npc.log("INFO", "Enqueueing the following programs into process queue for time: "..dump(time).."\n"
								..dump(programs_to_enqueue))
						_exec.priority_enqueue(self, programs_to_enqueue)
					end
					-- Clear programs_to_enqueue
					programs_to_enqueue = nil
					entries_to_enqueue = nil 
				end
			end
		-- else
		-- 	-- Check if lock can be released
		-- 	if (time % 1) > dtime + 0.1 then
		-- 		-- Release lock
		-- 		self.schedules.lock = false
		-- 	end
		end
	end
end

---------------------------------------------------------------------------------------
-- NPC Lua object functions
---------------------------------------------------------------------------------------
-- The following functions make up the definitions of on_rightclick(), do_custom()
-- and other functions that are assigned to the Lua entity definition
-- This function is executed each time the NPC is loaded
function npc.after_activate(self)
	--minetest.log("Self: "..dump(self))
	-- Reset animation
	if self.npc_state then
		if self.npc_state.movement then
			if self.npc_state.movement.is_sitting == true then
				npc.programs.instr.execute(self, npc.programs.instr.default.SIT, {pos=self.object:getpos()})
			elseif self.npc_state.movement.is_laying == true then
				npc.programs.instr.execute(self, npc.programs.instr.default.LAY, {pos=self.object:getpos()})
			end
			-- Reset yaw if available
			if self.yaw_before_interaction then
				self.object:setyaw(self.yaw_before_interaction)
			end
		end
    end
end

-- This function is executed on right-click
function npc.rightclick_interaction(self, clicker)
	-- Disable right click interaction per execution options
	local current_process = self.execution.process_queue[1]
	if current_process then
		if current_process.interrupt_options.allow_rightclick == false then
			npc.log("WARNING", "Attempted to right-click a NPC with disabled rightlick interaction")
			return
		end
	end

	-- Enqueue callback if any
	if npc.monitor.callback.exists(npc.monitor.callback.type.interaction, npc.monitor.callback.subtype.on_rightclick) then
		-- Enqueue all right-click callbacks for execution
		npc.monitor.callback.enqueue_all(self,
			npc.monitor.callback.type.interaction,
			npc.monitor.callback.subtype.on_rightclick)
	end

	-- Store original yaw
	self.yaw_before_interaction = self.object:getyaw()

	-- Rotate NPC toward its clicker
	npc.dialogue.rotate_npc_to_player(self)

	-- Get information from clicker
	local item = clicker:get_wielded_item()
	local name = clicker:get_player_name()

	npc.log("INFO", "Right-clicked NPC: "..dump(self))

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
end

function npc.step(self, dtime)
	if self.initialized == nil or self.initialized == false then
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
			end
		end
	end

	-- Execute monitor
	npc.monitor.execution_routine(self, dtime)

	-- Execute process scheduler
	npc.exec.execution_routine(self, dtime)

	-- Schedule timer
	npc.schedule.execution_routine(self, dtime)

	return false--self.freeze
end


---------------------------------------------------------------------------------------
-- NPC Definition
---------------------------------------------------------------------------------------
--mobs:register_mob("advanced_npc:npc", {
--	type = "npc",
--	passive = false,
--	damage = 3,
--	attack_type = "dogfight",
--	attacks_monsters = true,
--	-- Added group attack
--	group_attack = true,
--	-- Pathfinder = 2 to make NPCs more smart when attacking
--	pathfinding = 2,
--	hp_min = 10,
--	hp_max = 20,
--	armor = 100,
--	collisionbox = {-0.20,0,-0.20, 0.20,1.8,0.20},
--	--collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20},
--	--collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
--	visual = "mesh",
--	mesh = "character.b3d",
--	drawtype = "front",
--	textures = {
--		{"npc_male1.png"},
--		{"npc_male2.png"},
--		{"npc_male3.png"},
--		{"npc_male4.png"},
--		{"npc_male5.png"},
--		{"npc_male6.png"},
--		{"npc_male7.png"},
--		{"npc_male8.png"},
--		{"npc_male9.png"},
--		{"npc_male10.png"},
--		{"npc_male11.png"},
--		{"npc_male12.png"},
--		{"npc_male13.png"},
--		{"npc_male14.png"},
--		{"npc_female1.png"}, -- female by nuttmeg20
--		{"npc_female2.png"},
--		{"npc_female3.png"},
--		{"npc_female4.png"},
--		{"npc_female5.png"},
--		{"npc_female6.png"},
--		{"npc_female7.png"},
--		{"npc_female8.png"},
--		{"npc_female9.png"},
--		{"npc_female10.png"},
--		{"npc_female11.png"},
--	},
--	child_texture = {
--		{"npc_child_male1.png"},
--		{"npc_child_female1.png"},
--	},
--	makes_footstep_sound = true,
--	sounds = {},
--	-- Added walk chance
--	walk_chance = 20,
--	-- Added stepheight
--	stepheight = 0.6,
--	walk_velocity = 1,
--	run_velocity = 3,
--	jump = false,
--	drops = {
--		{name = "default:wood", chance = 1, min = 1, max = 3},
--		{name = "default:apple", chance = 2, min = 1, max = 2},
--		{name = "default:axe_stone", chance = 5, min = 1, max = 1},
--	},
--	water_damage = 0,
--	lava_damage = 2,
--	light_damage = 0,
--	--follow = {"farming:bread", "mobs:meat", "default:diamond"},
--	view_range = 15,
--	owner = "",
--	order = "follow",
--	--order = "stand",
--	fear_height = 3,
--	animation = {
--		speed_normal = 30,
--		speed_run = 30,
--		stand_start = 0,
--		stand_end = 79,
--		walk_start = 168,
--		walk_end = 187,
--		run_start = 168,
--		run_end = 187,
--		punch_start = 200,
--		punch_end = 219,
--	},
--	after_activate = function(self, staticdata, def, dtime)
--		npc.after_activate(self)
--	end,
--	on_rightclick = function(self, clicker)
--		-- Check if right-click interaction is enabled
--		if self.enable_rightclick_interaction == true then
--			npc.rightclick_interaction(self, clicker)
--		end
--	end,
--	do_custom = function(self, dtime)
--		return npc.step(self, dtime)
--	end
--})

-------------------------------------------------------------------------
-- Item definitions
-------------------------------------------------------------------------

--mobs:register_egg("advanced_npc:npc", S("NPC"), "default_brick.png", 1)

-- compatibility
--mobs:alias_mob("mobs:npc", "advanced_npc:npc")

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
