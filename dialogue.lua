-- NPC dialogue code by Zorman2000

npc.dialogue = {}

npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX = "Yes, give "
npc.dialogue.NEGATIVE_ANSWER_LABEL = "Nevermind"

npc.dialogue.MIN_DIALOGUES = 2
npc.dialogue.MAX_DIALOGUES = 4

-- This table contains the answers of dialogue boxes
npc.dialogue.dialogue_results = {
	options_dialogue = {},
	yes_no_dialogue = {}
}

-- Dialogue box definitions
-- The dialogue boxes are used for the player to interact with the
-- NPC in dialogues.
--------------------------------------------------------------------
-- Creates and shows a multi-option dialogue based on the number of responses
-- that the dialogue object contains
function npc.dialogue.show_options_dialogue(responses, dismiss_option_label, player_name) 
	local options_length = table.getn(responses) + 1	
	local formspec_height = (options_length * 0.7) + 0.7
	local formspec = "size[7,"..tostring(formspec_height).."]"

	for i = 1, #responses do
		local y = 0.7;
		if i > 1 then
			y = (y * i)
		end
		formspec = formspec.."button_exit[0.5,"..(y - 0.5)..";6,0.5;opt"..tostring(i)..";"..responses[i].text.."]"
	end
	formspec = formspec.."button_exit[0.5,"..(formspec_height - 0.7)..";6,0.5;exit;"..dismiss_option_label.."]"

	-- Create entry on options_dialogue table
	npc.dialogue.dialogue_results.options_dialogue[player_name] = {
		options = responses
	}

	minetest.show_formspec(player_name, "advanced_npc:options", formspec)
end

-- This function is used for showing a yes/no dialogue formspec
function npc.dialogue.show_yes_no_dialogue(prompt, 
										   positive_answer_label,
										   positive_callback,
										   negative_answer_label,
										   negative_callback,
										   player_name)

	local formspec = "size[7,3]"..
					 "label[0.5,0.1;"..prompt.."]"..
						"button_exit[0.5,1.15;6,0.5;yes_option;"..positive_answer_label.."]"..
						"button_exit[0.5,1.95;6,0.5;no_option;"..negative_answer_label.."]"	

	-- Create entry into responses table
	npc.dialogue.dialogue_results.yes_no_dialogue[player_name] = {
		yes_callback = positive_callback,
		no_callback = negative_callback
	}

	minetest.show_formspec(player_name, "advanced_npc:yes_no", formspec)
end

-- Dialogue methods
-- Select random dialogue objects for an NPC based on sex
-- and the relationship phase with player
function npc.dialogue.select_random_dialogues_for_npc(sex, phase)
	local result = {}
	local dialogues = npc.data.DIALOGUES.female
	if sex == npc.MALE then
		dialogues = npc.data.DIALOGUES.male
	end
	dialogues = dialogues[phase]

	-- Determine how many dialogue lines the NPC will have
	local number_of_dialogues = math.random(npc.dialogue.MIN_DIALOGUES, npc.dialogue.MAX_DIALOGUES)

	for i = 1,number_of_dialogues do
		result[i] = dialogues[math.random(1, #dialogues)]
	end

	return result
end

-- This function will choose randomly a dialogue from the NPC data
-- and process it. 
function npc.dialogue.start_dialogue(self, player)
	-- Choose a dialogue randomly
	local dialogue = self.dialogues[math.random(1, #self.dialogues)]
	npc.dialogue.process_dialogue(dialogue, player:get_player_name())
end

-- This function processes a dialogue object and performs
-- actions depending on what is defined in the object 
function npc.dialogue.process_dialogue(dialogue, player_name)
	-- Send dialogue line
	if dialogue.text then
		minetest.chat_send_player(player_name, dialogue.text)
	end

	-- Check if there are responses, then show multi-option dialogue if there are
	if dialogue.responses then
		npc.dialogue.show_options_dialogue(
			dialogue.responses, 
			npc.dialogue.NEGATIVE_ANSWER_LABEL,
			player_name
		)
	end
	-- TODO: Add support for flag, multi-option dialogue
	-- and their actions
end

-----------------------------------------------------------------------------
-- Functions for rotating NPC to look at player (taken from the API itself)
-----------------------------------------------------------------------------
local atan = function(x)
	if x ~= x then
		return 0
	else
		return math.atan(x)
	end
end


local function rotate_npc_to_player(self)
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

-- Handler for chat formspec
minetest.register_on_player_receive_fields(function (player, formname, fields)
	-- Additional checks for other forms should be handled here
	-- Handle yes/no dialogue
	if formname == "advanced_npc:yes_no" then
		local player_name = player:get_player_name()

		if fields then
			local player_response = npc.dialogue.dialogue_results.yes_no_dialogue[player_name]
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

			for i = 1, #player_response.options do
				local button_label = "opt"..tostring(i)
				if fields[button_label] then
					if player_response.options[i].action_type == "dialogue" then
						-- Process dialogue object
						npc.dialogue.process_dialogue(player_response.options[i].action, player_name)
					elseif player_response.options[i].action_type == "function" then
						-- Execute function
						-- Bug: for some reason function is null
						player_response.options[i].action()
					end
					return
				end
			end
		end
	end

end)
