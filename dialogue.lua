-- NPC dialogue code by Zorman2000
-- Dialogue definitions:
-- TODO: Complete
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
--   }
-- }

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

---------------------------------------------------------------------------------------
-- Dialogue box definitions
-- The dialogue boxes are used for the player to interact with the
-- NPC in dialogues.
---------------------------------------------------------------------------------------
-- Creates and shows a multi-option dialogue based on the number of responses
-- that the dialogue object contains
function npc.dialogue.show_options_dialogue(self, 
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
		is_married_dialogue = (dialogue.dialogue_type == npc.dialogue.dialogue_type.married),
		is_casual_trade_dialogue = (dialogue.dialogue_type == npc.dialogue.dialogue_type.casual_trade),
    is_dedicated_trade_dialogue = (dialogue.dialogue_type == npc.dialogue.dialogue_type.dedicated_trade),
    is_custom_trade_dialogue = (dialogue.dialogue_type == npc.dialogue.dialogue_type.custom_trade),
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

  	npc.lock_actions(self)

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

---------------------------------------------------------------------------------------
-- Dialogue methods
---------------------------------------------------------------------------------------
-- This function sets a unique response ID (made of <depth>:<response index>) to
-- each response that features a function. This is to be able to locate the
-- function easily later
local function set_response_ids_recursively(dialogue, depth, dialogue_id)
  -- Base case: dialogue object with no responses and no r,esponses below it
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


-- Select random dialogue objects for an NPC based on sex
-- and the relationship phase with player
function npc.dialogue.select_random_dialogues_for_npc(sex, phase, favorite_items, disliked_items)
	local result = {
		normal = {},
		hints = {}
	}

	local dialogues = npc.data.DIALOGUES.female
	if sex == npc.MALE then
		dialogues = npc.data.DIALOGUES.male
	end
	dialogues = dialogues[phase]

	-- Determine how many dialogue lines the NPC will have
	local number_of_dialogues = math.random(npc.dialogue.MIN_DIALOGUES, npc.dialogue.MAX_DIALOGUES)

	for i = 1,number_of_dialogues do
		local dialogue_id = math.random(1, #dialogues)
		result.normal[i] = dialogues[dialogue_id] 

    set_response_ids_recursively(result.normal[i], 0, dialogue_id)
	end

	-- Add item hints.
	-- Favorite items
	for i = 1, 2 do
		result.hints[i] = {}
		result.hints[i].text = 
			npc.relationships.get_hint_for_favorite_item(favorite_items["fav"..tostring(i)], sex, phase)
	end

	-- Disliked items
	for i = 3, 4 do
		result.hints[i] = {}
		result.hints[i].text = 
			npc.relationships.get_hint_for_disliked_item(disliked_items["dis"..tostring(i-2)], sex)
	end

	return result
end

-- This function creates a multi-option dialogue from the custom trades that the
-- NPC have.
function npc.dialogue.create_custom_trade_options(self, player)
  -- Create the action for each option
  local actions = {}
  for i = 1, #self.trader_data.custom_trades do
    table.insert(actions, function() npc.trade.show_custom_trade_offer(self, player, self.trader_data.custom_trades[i]) end)   
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
    dialogue = npc.trade.DEDICATED_TRADER_PROMPT
    npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
    return
  end

	local chance = math.random(1, 100)
	minetest.log("Chance: "..dump(chance))
	if chance < 30 then
		-- If NPC is a casual trader, show a sell or buy dialogue 30% of the time, depending
		-- on the state of the casual trader.
    if self.trader_data.trader_status == npc.trade.NONE then
      -- Show custom trade options if available
      if table.getn(self.trader_data.custom_trades) > 0 then
        -- Show custom trade options
        dialogue = npc.dialogue.create_custom_trade_options(self, player)
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
  			dialogue = npc.trade.CASUAL_TRADE_BUY_DIALOGUE
  		elseif trade_chance == 2 then
  			-- Show casual sell dialogue
  			dialogue = npc.trade.CASUAL_TRADE_SELL_DIALOGUE
  		elseif trade_chance == 3 then
        -- Show custom trade options
        dialogue = npc.dialogue.create_custom_trade_options(self, player)
      end
  	end
	elseif chance >= 30 and chance < 90 then
    -- Choose a random dialogue from the common ones
		dialogue = self.dialogues.normal[math.random(1, #self.dialogues.normal)]
	elseif chance >= 90 then
    -- Choose a random dialogue line from the favorite/disliked item hints
		dialogue = self.dialogues.hints[math.random(1, 4)]
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
  npc.lock_actions(self)

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
    npc.unlock_actions(self)
  end

	-- Check if there are responses, then show multi-option dialogue if there are
	if dialogue.responses then
		npc.dialogue.show_options_dialogue(
			self,
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
    minetest.log("N1: "..dump(string.sub(response_id, 0, d_i1))..", N2: "..dump(string.sub(response_id, 1, d_i1-1)))
    local depth = tonumber(string.sub(response_id, 0, d_i1-1))
    local id = tonumber(string.sub(response_id, d_i2 + 1))
    minetest.log("Depth: "..dump(depth)..", id: "..dump(id))
    -- Check each response
    for key,value in ipairs(dialogue.responses) do
      minetest.log("Key: "..dump(key)..", value: "..dump(value)..", comp1: "..dump(current_depth == depth))
      if value.action_type == "function" then
        -- Check if we are on correct response and correct depth
        if current_depth == depth then
          if key == id then
            return value
          end
        end
      else
        minetest.log("Entering again...")
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
     		npc.unlock_actions(player_response.npc)

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
       			npc.unlock_actions(player_response.npc)
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
                
						elseif player_response.is_casual_trade_dialogue == true then
							-- Check if trade is casual buy or sell
							if player_response.casual_trade_type == npc.trade.OFFER_BUY then
								-- Get functions from casual buy dialogue
								npc.trade.CASUAL_TRADE_BUY_DIALOGUE
									.responses[player_response.options[i].response_id]
									.action(player_response.npc, player)
							elseif player_response.casual_trade_type == npc.trade.OFFER_SELL == true then
								-- Get functions from casual sell dialogue
								npc.trade.CASUAL_TRADE_SELL_DIALOGUE
									.responses[player_response.options[i].response_id]
									.action(player_response.npc, player) 
							end
			              	return
			            elseif player_response.is_dedicated_trade_dialogue == true then
			              -- Get the functions for a dedicated trader prompt
			              npc.trade.DEDICATED_TRADER_PROMPT
			                .responses[player_response.options[i].response_id]
			                .action(player_response.npc, player)
			              return
			            elseif player_response.is_custom_trade_dialogue == true then
			              -- Functions for a custom trade should be available from the same dialogue
			              -- object as it is created in memory
			              minetest.log("Player response: "..dump(player_response.options[i]))
			              player_response.options[i].action(player_response.npc, player)
									else
										-- Get dialogues for sex and phase
										local dialogues = npc.data.DIALOGUES[player_response.npc.sex][phase]

			              minetest.log("Object: "..dump(dialogues[player_response.options[i].dialogue_id]))
			              local response = get_response_object_by_id_recursive(dialogues[player_response.options[i].dialogue_id], 0, player_response.options[i].response_id)
			              minetest.log("Found: "..dump(response))
			              
			              -- Execute function
			              response.action(player_response.npc, player)

										-- Execute function
										-- dialogues[player_response.options[i].dialogue_id]
										-- 	.responses[player_response.options[i].response_id]
										-- 	.action(player_response.npc, player)

			              -- Unlock queue, reset action timer and unfreeze NPC.
			              npc.unlock_actions(player_response.npc)

						end
					end
					return
				end
			end
		end
	end

end)
