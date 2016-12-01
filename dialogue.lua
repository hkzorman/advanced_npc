-- NPC dialogue code by Zorman2000

npc.dialogue = {}

npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX = "Yes, give "
npc.dialogue.NEGATIVE_ANSWER_LABEL = "Nevermind"

npc.dialogue.MIN_DIALOGUES = 2
npc.dialogue.MAX_DIALOGUES = 4

-- This table contains the answers of dialogue boxes
npc.dialogue.dialogue_results = {
	yes_no_dialogue = {}
}

-- Dialogue box definitions
-- The dialogue boxes are used for the player to interact with the
-- NPC in dialogues.
--------------------------------------------------------------------
-- Multi-option dialogue
local function create_formspec(options, close_option) 
	local options_length = table.getn(options) + 1	
	local formspec_height = (options_length * 0.7) + 1
	local formspec = "size[7,"..tostring(formspec_height).."]"
	for i, opt in ipairs(options) do
		local y = 0.7;
		if i > 1 then
			y = (y * i)
		end
		formspec = formspec.."button[0.5,"..y..";6,0.5;opt"..tostring(i)..";"..options[i].opt.."]"
	end
	formspec = formspec.."button_exit[0.5,"..(formspec_height - 1)..";6,0.5;exit;"..close_option.."]"
	return formspec
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
	npc.dialogue.dialogue_results.yes_no_dialogue[1] = {
		name = player_name, 
		response = "",
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

---------------------------------------------------------------------
-- Drives conversation
---------------------------------------------------------------------
local function show_chat_option(npc_name, self, player_name, chat_options, close_option)
	rotate_npc_to_player(self)
	self.order = "stand"
	
	local chatline = get_random_chatline(chat_options)
	minetest.chat_send_player(player_name, chatline.text)
	if chatline.options ~= nil then
		minetest.log("Current options: "..dump(chatline.options))
		local formspec = create_formspec(chatline.options, close_option)
		minetest.show_formspec(player_name, "rndform", formspec)
	end
	
	self.order = "follow"
end

-- Function to get response by player name
local function get_yes_no_dialogue_response_by_player_name(player_name)
	for i = 1,#npc.dialogue.dialogue_results.yes_no_dialogue do
		local current_result = npc.dialogue.dialogue_results.yes_no_dialogue[i]
		if current_result.name == player_name then
			return current_result
		end
	end
	return nil
end

-- Handler for chat formspec
minetest.register_on_player_receive_fields(function (player, formname, fields)
	-- Additional checks for other forms should be handled here
	if formname == "advanced_npc:yes_no" then
		local player_name = player:get_player_name()

		if fields then
			local player_response = get_yes_no_dialogue_response_by_player_name(player_name)
			if fields.yes_option then
				player_response.response = true
				player_response.yes_callback()
			elseif fields.no_option then
				player_response.response = false
				player_response.no_callback()
			end
			minetest.log(player_name.." chose response: "
				..dump(get_yes_no_dialogue_response_by_player_name(player_name).response))
		end
	end

end)
