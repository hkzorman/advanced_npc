-- NPC Chat code by Zorman2000
-- Chat system consists of chatline and options objects that are re-used to create a conversation. 
-- The objects are the following:
-- 
-- chatline = { text = "", options = {}, name = "", flag = "" }
--  1. text: What the NPC says on this chat line
--  2. options: What the player can answer to the chat line. Options are of another type of chat lines.
--              If you want the player to have no options to answer, set to nil
--  3. name: The name of the NPC that will use this line. Use this when you want a specific NPC
--           to speak this line.
--  4. flag: When the NPC speaks this line, this flag will be set into the entity's metadata.
--
-- options = { opt = "", answer = { chatline }
--  1. opt: The text that the player can say to the NPC
--  2. answer: A chatline object (as described above)
-- 
-- Example of conversation hierarchy
-- chat_options = {
--  	chatline1 = { text = "Q1", options = { 
--  		option1 = { opt = "O1", answer = { 
--  			chatline = { text = "A1", options = nil } 
--  		} 
--  	},
--  	chatline2 = { text = "Q2", options = nil }
--  }

local options = {"Question 1","Question 2","Question 3","Question 4"} 

npc.dialogue = {}

npc.dialogue.YES_GIFT_ANSWER_LABEL = "Yes, give wielded item"
npc.dialogue.NO_GIFT_ANSWER_LAEBL = "Nevermind"

---------------------------------------------------------------------
-- Creates a formspec for dialog
--------------------------------------------------------------------
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

-- New function for getting dialogue formspec
function npc.dialogue.show_yes_no_dialogue(prompt, player_name)
	

	-- Send prompt message to player
	minetest.chat_send_player(player_name, prompt)

	dialogue_form:show(player_name)

	return dialogue_result
end

---------------------------------------------------------------------
-- Returns all chatlines for a specific NPC
---------------------------------------------------------------------
local function get_chatline_for_npc(chat_options, npc_name)
	local result = {}
	for i,chatline in ipairs(chat_options) do
		if chatline.name == npc_name then
			table.insert(result, chatline)
		end
	end
	return result
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
