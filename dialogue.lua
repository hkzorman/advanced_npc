-------------------------------------------------------------------------------------
-- NPC dialogue code by Zorman2000
-------------------------------------------------------------------------------------

npc.dialogue = {}

npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX = "Yes, give "
npc.dialogue.NEGATIVE_ANSWER_LABEL = "Nevermind"

npc.dialogue.MIN_DIALOGUES = 2
npc.dialogue.MAX_DIALOGUES = 4

npc.dialogue.dialogue_type = {
	married = 1,
	casual_trade = 2,
	dedicated_trade = 3,
	custom_trade = 4
}

-- This table contains the answers of dialogue boxes
npc.dialogue.dialogue_results = {
	options_dialogue = {},
	yes_no_dialogue = {}
}

npc.dialogue.tags = {
	UNISEX = "unisex",
	MALE = "male",
	FEMALE = "female",
	-- Relationship based tags - these are one-to-one with the
	-- phase names.
	DEFAULT_MARRIED_DIALOGUE = "default_married_dialogue",
	PHASE_1 = "phase1",
	PHASE_2 = "phase2",
	PHASE_3 = "phase3",
	PHASE_4 = "phase4",
	PHASE_5 = "phase5",
	GIFT_ITEM_HINT = "gift_item_hint",
	GIFT_ITEM_RESPONSE = "gift_item_response",
	GIFT_ITEM_LIKED = "gift_item_liked",
	GIFT_ITEM_UNLIKED = "gift_item_unliked",
	-- Trade-related tags
	DEFAULT_CASUAL_TRADE = "default_casual_trade_dialogue",
	DEFAULT_DEDICATED_TRADE = "default_dedicated_trade_dialogue",
	DEFAULT_BUY_OFFER = "buy_offer",
	DEFAULT_SELL_OFFER = "sell_offer",
	-- Occupation-based tags - these are one-to-one with the 
	-- default occupation names
	BASIC = "basic", -- Dialogues related to the basic occupation should
	-- use this. As basic occupation is generic, any occupation
	-- should be able to use these dialogues.
	DEFAULT_FARMER = "default_farmer",
	DEFAULT_COOKER = "default_cooker"
}

-- This table will contain all the registered dialogues for NPCs
npc.dialogue.registered_dialogues = {}

npc.dialogue.cache_keys = {
	CASUAL_BUY_DIALOGUE = {key="CASUAL_BUY_DIALOGUE", tags={npc.dialogue.tags.DEFAULT_CASUAL_TRADE, npc.dialogue.tags.DEFAULT_BUY_OFFER}},
	CASUAL_SELL_DIALOGUE = {key="CASUAL_SELL_DIALOGUE", tags={npc.dialogue.tags.DEFAULT_CASUAL_TRADE, npc.dialogue.tags.DEFAULT_SELL_OFFER}},
	DEDICATED_TRADER_DIALOGUE = {key="DEDICATED_TRADER_DIALOGUE", tags={npc.dialogue.tags.DEFAULT_DEDICATED_TRADE}},
	MARRIED_DIALOGUE = {key="MARRIED_DIALOGUE", tags={npc.dialogue.tags.DEFAULT_MARRIED_DIALOGUE}},
}

npc.dialogue.cache = {}

--------------------------------------------------------------------------------------
-- Dialogue registration functions
-- All dialogues will be registered by providing a definition.
-- A unique key will be assigned to them. The dialogue definition is the following:
-- {
--   text: "",
--   ^ The "spoken" dialogue line
--   flag:
--   ^ If the flag with the specified name has the specified value
--     then this dialogue is valid 
--   {
--     name: ""   
--     ^ Name of the flag
--     value:  
--     ^ Expected value of the flag. A flag can be a function. In such a case, it is
--       expected the function will return this value.
--   },
--   tags = {
--		-- Tags are an array of string that allow to classify dialogues
--		-- A dialogue can have as many tags as desired and can take any form.
--      -- However, for consistency, some predefined tags can be found at
--		-- npc.dialogue.tags.
--		-- Example:
--		"phase1",
--		"any"
--	 }
--	 responses = {
--		-- Array of responses the player can choose. A response can be of
--		-- two types: as [1] or as [2] (see example below)
--		[1] = {
--			text = "Yes",
--			-- Text displayed to the player
--			action_type = "dialogue",
--			-- Type of action that happens when the player chooses this response.
--			--  can be "dialogue" or "function". This example shows "dialogue"
--			action = {
--				text = "It's so beautiful, and big, and large, and infinite, and..."
--			},
--		},
--			-- A table containing a dialogue. This means you can include not only
--			-- text but also flag and responses as well. Dialogues are recursive.
--		[2] = {
--			text = "No",
--			action_type = "function",
--			action = function(self, player)
--				-- A function will have access to self, which is the NPC
--				-- and the player, which is the player ObjectRef. You can
--				-- pretty much do anything here. The example here is very simple,
--				-- just sending a chat message. But you can add items to players
--				-- or to NPCs and so on.
--	          	minetest.chat_send_player(player:get_player_name(), "Oh, ok...")
--	        end,
--		},	
--	 }
-- }
--------------------------------------------------------------------------------------
-- This function sets a unique response ID (made of <depth>:<response index>) to
-- each response that features a function. This is to be able to locate the
-- function easily later
local function set_response_ids_recursively(dialogue, depth, dialogue_id)
	-- Base case: dialogue object with no responses and no responses below it
	if dialogue.responses == nil
			and (dialogue.action_type == "dialogue" and dialogue.action.responses == nil) then
		return
	elseif dialogue.responses ~= nil then
		-- Assign a response ID to each response
		local response_id_prefix = tostring(depth)..":"
		for key,value in ipairs(dialogue.responses) do
			if value.action_type == "function" then
				value.response_id = response_id_prefix..key
				value.dialogue_id = dialogue_id
			else
				-- We have a dialogue action type. Need to check if dialogue has further responses
				if value.action.responses ~= nil then
					set_response_ids_recursively(value.action, depth + 1, dialogue_id)
				end
			end
		end
	end
end

-- The register dialogue function will just receive the definition as 
-- explained above. The unique key will be the index it gets into the
-- array when inserted.
function npc.dialogue.register_dialogue(def)
	-- If def has not tags then apply the default ones
	if not def.tags then
		def.tags = {npc.dialogue.tags.UNISEX, npc.dialogue.tags.PHASE_1}
	end

	local dialogue_id = table.getn(npc.dialogue.registered_dialogues) + 1
	-- Set the response IDs - required for dialogue objects that
	-- form trees of dialogues
	set_response_ids_recursively(def, 0, dialogue_id)

	def.key = dialogue_id

	-- Insert dialogue into table
	table.insert(npc.dialogue.registered_dialogues, def)
	return dialogue_id
end

-- This function returns a table of dialogues that meet the given
-- tags array. The keys in the table are the keys in 
-- npc.dialogue.registered_dialogues, therefore you can use them to 
--retrieve specific dialogues. However, it should be stored by the NPC.
function npc.dialogue.search_dialogue_by_tags(tags, find_all)
	--minetest.log("Tags being searched: "..dump(tags))
	local result = {}
	for key, def in pairs(npc.dialogue.registered_dialogues) do
		-- Check if def.tags have any of the provided tags
		local tags_found = 0
		--minetest.log("Tags on dialogue def: "..dump(def.tags))
		for i = 1, #tags do
			if npc.utils.array_contains(def.tags, tags[i]) then
				tags_found = tags_found + 1
			end
		end
		--minetest.log("Tags found: "..dump(tags_found))
		-- Check if we found all tags
		if find_all then
			if tags_found == #tags then
				-- Add result
				result[key] = def
			end
		elseif not find_all then
			if tags_found == #tags or tags_found == #def.tags then
				-- Add result
				result[key] = def
			end
		end
	end
	return result
end

function npc.dialogue.get_cached_dialogue_key(_cache_key, tags)
	local cache_key = _cache_key
	if type(_cache_key) == "table" then
		cache_key = _cache_key.key
		tags = _cache_key.tags
	end

	local key = npc.dialogue.cache[cache_key]
	-- Check if key isn't cached
	if not key then
		-- Search for the dialogue
		local dialogues = npc.dialogue.search_dialogue_by_tags(tags, true)
		key = npc.utils.get_map_keys(dialogues)[1]
		-- Populate cache
		npc.dialogue.cache[cache_key] = key
		-- Return key
		return key
	else
		-- Return the cached key
		return key
	end
end

--------------------------------------------------------------------------------------
-- Dialogue box definitions
-- The dialogue boxes are used for the player to interact with the
-- NPC in dialogues.
--------------------------------------------------------------------------------------
-- Creates and shows a multi-option dialogue based on the number of responses
-- that the dialogue object contains
function npc.dialogue.show_options_dialogue(self,
dialogue_key,
dialogue,
dismiss_option_label,
player_name)
	local responses = dialogue.responses
	local options_length = table.getn(responses) + 1
	local formspec_height = (options_length * 0.7) + 0.4
	local formspec = "size[7,"..tostring(formspec_height).."]"

	for i = 1, #responses do
		local y = 0.8;
		if i > 1 then
			y = (0.75 * i)
		end
		formspec = formspec.."button_exit[0.5,"
				..(y - 0.5)..";6,0.5;opt"..tostring(i)..";"..responses[i].text.."]"
	end
	formspec = formspec.."button_exit[0.5,"
			..(formspec_height - 0.7)..";6,0.5;exit;"..dismiss_option_label.."]"

	-- Create entry on options_dialogue table
	npc.dialogue.dialogue_results.options_dialogue[player_name] = {
		npc = self,
		dialogue = dialogue,
		dialogue_key = dialogue_key,
		is_married_dialogue =
		(dialogue.dialogue_type == npc.dialogue.dialogue_type.married),
		is_custom_trade_dialogue =
		(dialogue.dialogue_type == npc.dialogue.dialogue_type.custom_trade),
		casual_trade_type = dialogue.casual_trade_type,
		options = responses
	}

	minetest.show_formspec(player_name, "advanced_npc:options", formspec)
end

-- This function is used for showing a yes/no dialogue formspec
function npc.dialogue.show_yes_no_dialogue(self,
prompt,
positive_answer_label,
positive_callback,
negative_answer_label,
negative_callback,
player_name)

	npc.exec.set_input_wait_state(self)

	local formspec = "size[7,3]"..
			"label[0.5,0.1;"..prompt.."]"..
			"button_exit[0.5,1.15;6,0.5;yes_option;"..positive_answer_label.."]"..
			"button_exit[0.5,1.95;6,0.5;no_option;"..negative_answer_label.."]"

	-- Create entry into responses table
	npc.dialogue.dialogue_results.yes_no_dialogue[player_name] = {
		npc = self,
		yes_callback = positive_callback,
		no_callback = negative_callback
	}

	minetest.show_formspec(player_name, "advanced_npc:yes_no", formspec)
end

--------------------------------------------------------------------------------------
-- Dialogue methods
--------------------------------------------------------------------------------------
-- Select random dialogue objects for an NPC based on gender
-- and the relationship phase with player
function npc.dialogue.select_random_dialogues_for_npc(self, phase)
	local result = {
		normal = {},
		hints = {}
	}

	local phase_tag = "phase1"
	if phase then
		phase_tag = phase
	end

	local search_tags = {
		"unisex",
		self.gender,
		phase_tag,
		self.occupation
	}

	local dialogues = npc.dialogue.search_dialogue_by_tags(search_tags)
	if dialogues and next(dialogues) ~= nil then
		local keys = npc.utils.get_map_keys(dialogues)

		-- Determine how many dialogue lines the NPC will have
		local number_of_dialogues = math.random(npc.dialogue.MIN_DIALOGUES, npc.dialogue.MAX_DIALOGUES)

		for i = 1, number_of_dialogues do
			local key_id = math.random(1, #keys)
			result.normal[i] = keys[key_id]
			npc.log("DEBUG", "Adding dialogue: "..dump(dialogues[keys[key_id]]))
		end

		-- Add item hints.
		for i = 1, 2 do
			local hints = npc.relationships.get_dialogues_for_gift_item(
				self.gift_data.favorite_items["fav"..tostring(i)],
				npc.dialogue.tags.GIFT_ITEM_HINT,
				npc.dialogue.tags.GIFT_ITEM_LIKED,
				self.gender,
				phase_tag)
			for key, value in pairs(hints) do
				result.hints[i] = key
			end
		end

		for i = 3, 4 do
			local hints = npc.relationships.get_dialogues_for_gift_item(
				self.gift_data.disliked_items["dis"..tostring(i-2)],
				npc.dialogue.tags.GIFT_ITEM_HINT,
				npc.dialogue.tags.GIFT_ITEM_UNLIKED,
				self.gender)
			for key, value in pairs(hints) do
				result.hints[i] = key
			end
		end
	end

	npc.log("DEBUG", "Dialogue results:"..dump(result))
	return result
end

-- This function creates a multi-option dialogue from the custom trades that the
-- NPC have.
function npc.dialogue.create_custom_trade_options(self, player)
	-- Create the action for each option
	local actions = {}
	for i = 1, #self.trader_data.custom_trades do
		table.insert(actions,
			function()
				npc.trade.show_custom_trade_offer(self, player, self.trader_data.custom_trades[i])
			end)
	end
	-- Default text to be shown for dialogue prompt
	local text = npc.trade.CUSTOM_TRADES_PROMPT_TEXT
	-- Get the options from each custom trade entry
	local options = {}
	if #self.trader_data.custom_trades == 1 then
		table.insert(options, self.trader_data.custom_trades[1].button_prompt)
		text = self.trader_data.custom_trades[1].option_prompt
	else
		for i = 1, #self.trader_data.custom_trades do
			table.insert(options, self.trader_data.custom_trades[i].button_prompt)
		end
	end
	-- Create dialogue object
	local dialogue = npc.dialogue.create_option_dialogue(text, options, actions)
	dialogue.dialogue_type = npc.dialogue.dialogue_type.custom_trade

	return dialogue
end

-- This function will choose randomly a dialogue from the NPC data
-- and process it. 
function npc.dialogue.start_dialogue(self, player, show_married_dialogue)
	-- Choose a dialogue randomly
	local dialogue = {}

	-- Construct dialogue for marriage
	if npc.relationships.get_relationship_phase(self, player:get_player_name()) == "phase6"
			and show_married_dialogue == true then
		dialogue = npc.relationships.MARRIED_NPC_DIALOGUE
		npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
		return
	end

	-- Show options dialogue for dedicated trader
	if self.trader_data.trader_status == npc.trade.TRADER then
		dialogue = npc.dialogue.get_cached_dialogue_key(npc.dialogue.cache_keys.DEDICATED_TRADER_DIALOGUE)
		npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
		return
	end

	local chance = math.random(1, 100)
	--minetest.log("Chance: "..dump(chance))
	if chance < 30 then
		-- Show trading options for casual traders
		-- If NPC has custom trading options, these will be
		-- shown as well with equal chance as the casual
		-- buy/sell options
		if self.trader_data.trader_status == npc.trade.NONE then
			-- Show custom trade options if available
			if table.getn(self.trader_data.custom_trades) > 0 then
				-- Show custom trade options
				dialogue = npc.dialogue.create_custom_trade_options(self, player)
			else
				-- If not available, choose normal dialogue
				dialogue = self.dialogues.normal[math.random(1, #self.dialogues.normal)]
			end
		elseif self.trader_data.trader_status == npc.trade.CASUAL then
			local max_trade_chance = 2
			if table.getn(self.trader_data.custom_trades) > 0 then
				max_trade_chance = 3
			end
			-- Show buy/sell with 50% chance each
			local trade_chance = math.random(1, max_trade_chance)
			if trade_chance == 1 then
				-- Show casual buy dialogue
				dialogue = npc.dialogue.get_cached_dialogue_key(npc.dialogue.cache_keys.CASUAL_BUY_DIALOGUE)
			elseif trade_chance == 2 then
				-- Show casual sell dialogue
				dialogue = npc.dialogue.get_cached_dialogue_key(npc.dialogue.cache_keys.CASUAL_SELL_DIALOGUE)
			elseif trade_chance == 3 then
				-- Show custom trade options
				dialogue = npc.dialogue.create_custom_trade_options(self, player)
			end
		end
	elseif chance >= 30 and chance < 90 then
		-- Choose a random dialogue from the common ones
		dialogue = self.dialogues.normal[math.random(1, #self.dialogues.normal)]
	elseif chance >= 90 then
		-- Check if gift items hints are enabled
		minetest.log("Self gift data enable: "..dump(self.gift_data.enable_gift_items_hints))
		if self.gift_data.enable_gift_items_hints then
			-- Choose a random dialogue line from the favorite/disliked item hints
			dialogue = self.dialogues.hints[math.random(1, 4)]
		else
			-- Choose a random dialogue from the common ones
			dialogue = self.dialogues.normal[math.random(1, #self.dialogues.normal)]
		end
	end

	local dialogue_result = npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
	if dialogue_result == false then
		-- Try to find another dialogue line
		npc.dialogue.start_dialogue(self, player, show_married_dialogue)
	end
end

-- This function processes a dialogue object and performs
-- actions depending on what is defined in the object
function npc.dialogue.process_dialogue(self, dialogue, player_name)
	-- Freeze NPC actions
	npc.exec.set_input_wait_state(self)
	--npc.lock_actions(self)

	local dialogue_key = -1

	if type(dialogue) ~= "table" then
		dialogue_key = dialogue
		dialogue = npc.dialogue.registered_dialogues[dialogue]
		--minetest.log("Found dialogue: "..dump(dialogue))
	end

	-- Check if this dialogue has a flag definition
	if dialogue.flag then
		-- Check if the NPC has this flag
		local flag_value = npc.get_flag(self, dialogue.flag.name)
		if flag_value ~= nil then
			-- Check if value of the flag is equal to the expected value
			if flag_value ~= dialogue.flag.value then
				-- Do not process this dialogue
				return false
			end
		else

			if (type(dialogue.flag.value) == "boolean" and dialogue.flag.value ~= false)
					or (type(dialogue.flag.value) == "number" and dialogue.flag.value > 0) then
				-- Do not process this dialogue
				return false
			end
		end
	end

	-- Send dialogue line
	if dialogue.text then
		npc.chat(self.npc_name, player_name, dialogue.text)
	end

	-- Check if dialogue has responses. If it doesn't, unlock the actions
	-- queue and reset actions timer.'
	if not dialogue.responses then
		npc.exec.set_ready_state(self)
	end

	-- Check if there are responses, then show multi-option dialogue if there are
	if dialogue.responses then
		npc.dialogue.show_options_dialogue(
			self,
			dialogue_key,
			dialogue,
			npc.dialogue.NEGATIVE_ANSWER_LABEL,
			player_name
		)
	end

	-- Dialogue object processed successfully
	return true
end

function npc.dialogue.create_option_dialogue(prompt, options, actions)
	local result = {}
	result.text = prompt
	result.responses = {}
	for i = 1, #options do
		table.insert(result.responses, {text = options[i], action_type="function", action=actions[i]})
	end
	return result
end

-----------------------------------------------------------------------------
-- Functions for rotating NPC to look at player
-- (taken from the mobs_redo API)
-----------------------------------------------------------------------------
local atan = function(x)
	if x ~= x then
		return 0
	else
		return math.atan(x)
	end
end

function npc.dialogue.rotate_npc_to_player(self)
	local s = self.object:getpos()
	local objs = minetest.get_objects_inside_radius(s, 4)
	local lp = nil
	local yaw = 0

	for n = 1, #objs do
		if objs[n]:is_player() then
			lp = objs[n]:getpos()
			break
		end
	end
	if lp then
		local vec = {
			x = lp.x - s.x,
			y = lp.y - s.y,
			z = lp.z - s.z
		}

		yaw = (atan(vec.z / vec.x) + math.pi / 2) - self.rotate

		if lp.x > s.x then
			yaw = yaw + math.pi
		end
	end
	self.object:setyaw(yaw)
end

---------------------------------------------------------------------------------------
-- Answer processing functions
---------------------------------------------------------------------------------------
-- This function locates a response object that has function on the dialogue tree.
local function get_response_object_by_id_recursive(dialogue, current_depth, response_id)
	if dialogue.responses == nil
			and (dialogue.action_type == "dialogue" and dialoge.action.responses == nil) then
		return nil
	elseif dialogue.responses ~= nil then
		-- Get current depth and response ID
		local d_i1, d_i2 = string.find(response_id, ":")
		--minetest.log("N1: "..dump(string.sub(response_id, 0, d_i1))..", N2: "..dump(string.sub(response_id, 1, d_i1-1)))
		local depth = tonumber(string.sub(response_id, 0, d_i1-1))
		local id = tonumber(string.sub(response_id, d_i2 + 1))
		--minetest.log("Depth: "..dump(depth)..", id: "..dump(id))
		-- Check each response
		for key,value in ipairs(dialogue.responses) do
			--minetest.log("Key: "..dump(key)..", value: "..dump(value)..", comp1: "..dump(current_depth == depth))
			if value.action_type == "function" then
				-- Check if we are on correct response and correct depth
				if current_depth == depth then
					if key == id then
						return value
					end
				end
			else
				--minetest.log("Entering again...")
				-- We have a dialogue action type. Need to check if dialogue has further responses
				if value.action.responses ~= nil then
					local response = get_response_object_by_id_recursive(value.action, current_depth + 1, response_id)
					if response ~= nil then
						return response
					end
				end
			end
		end
	end
end

-- Handler for dialogue formspec
minetest.register_on_player_receive_fields(function (player, formname, fields)
	-- Additional checks for other forms should be handled here
	-- Handle yes/no dialogue
	if formname == "advanced_npc:yes_no" then
		local player_name = player:get_player_name()

		if fields then
			local player_response = npc.dialogue.dialogue_results.yes_no_dialogue[player_name]

			-- Unlock queue, reset action timer and unfreeze NPC.
			npc.exec.set_ready_state(player_response.npc)

			if fields.yes_option then
				player_response.yes_callback()
			elseif fields.no_option then
				player_response.no_callback()
			end
		end
	end

	-- Manage options dialogue
	if formname == "advanced_npc:options" then
		local player_name = player:get_player_name()

		if fields then
			-- Get player response
			local player_response = npc.dialogue.dialogue_results.options_dialogue[player_name]

			-- Check if the player hit the negative option or esc button
			if fields["exit"] or fields["quit"] == "true" then
				-- Unlock queue, reset action timer and unfreeze NPC.
				npc.exec.set_ready_state(player_response.npc)
			end

			for i = 1, #player_response.options do
				local button_label = "opt"..tostring(i)
				if fields[button_label] then
					if player_response.options[i].action_type == "dialogue" then
						-- Process dialogue object
						npc.dialogue.process_dialogue(player_response.npc,
							player_response.options[i].action,
							player_name)
					elseif player_response.options[i].action_type == "function" then
						-- Execute function - get it directly from definition
						-- Find NPC relationship phase with player
						local phase =
						npc.relationships.get_relationship_phase(player_response.npc, player_name)
						-- Check if NPC is married and the married NPC dialogue should be shown
						if phase == "phase6" and player_response.is_married_dialogue == true then
							-- Get the function definitions from the married dialogue
							npc.relationships.MARRIED_NPC_DIALOGUE
							.responses[player_response.options[i].response_id]
							.action(player_response.npc, player)
						elseif player_response.is_custom_trade_dialogue == true then
							-- Functions for a custom trade should be available from the same dialogue
							-- object as they are created on demand
							minetest.log("Player response: "..dump(player_response.options[i]))
							player_response.options[i].action(player_response.npc, player)
						else
							-- Get dialogue from registered dialogues
							local dialogue = npc.dialogue.registered_dialogues[player_response.options[i].dialogue_id]
							local response = get_response_object_by_id_recursive(dialogue, 0, player_response.options[i].response_id)

							-- Execute function
							response.action(player_response.npc, player)

							-- Unlock queue, reset action timer and unfreeze NPC.
							npc.exec.set_ready_state(player_response.npc)
						end
					end
					return
				end
			end
		end
	end

end)
