
local S = mobs.intllib

-- Npc by TenPlus1

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

local chat_options = {
	{ text = "Don't talk with me know, please", options = nil, name = "Angry Guy" },
	{ text = "Hello, how are you doing?", options = {
			{ opt = "Good", answer = 
				{ text = "That's good. Take care of yourself.", options = nil } 
			},
			{ opt = "Great! And you?", answer = 
				{ text = "I'm doing well, thank you. See ya around!", options = nil }
			},
			{ opt = "Not so well...", answer = 
				{ text = "Hey, why not feeling good? What's wrong?", options = {
						{ opt = "Not your business!", answer = 
							{ text = "So rude! Don't speak to me anymore!", options = nil, flag = "not_speak" } 
						},
						{ opt = "It's nothing! But thank you for asking!", answer = 
							{ text = "Ok my friend. See ya around!", options = nil }
						},
					}
				}
			}
		}
	},
	{ text = "I'm thinking of buying something but not sure...", options = nil },
	{ text = "I have traveled around the world and only like this place...", options = nil }
}


local options = {"Question 1","Question 2","Question 3","Question 4"}

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

---------------------------------------------------------------------
-- Returns a random chatline for unimportant NPCs
---------------------------------------------------------------------
local function get_random_chatline(chat_options)
	local chat_options_length = table.getn(chat_options)
	local random_option = math.random(1, chat_options_length - 1)
	local found = false
	while found == false do
		for i,chatline in ipairs(chat_options) do
			if i == random_option and chatline.name == nil then
				found = true
				return chatline
			end
		end
	end
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




mobs.npc_drops = {
	"default:pick_steel", "mobs:meat", "default:sword_steel",
	"default:shovel_steel", "farming:bread", "bucket:bucket_water"
}

mobs:register_mob("mobs_npc:npc", {
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
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "character.b3d",
	drawtype = "front",
	textures = {
		{"mobs_npc.png"},
		{"mobs_npc2.png"}, -- female by nuttmeg20
	},
	child_texture = {
		{"mobs_npc_baby.png"}, -- derpy baby by AmirDerAssassine
	},
	makes_footstep_sound = true,
	sounds = {},
	-- Added walk chance
	walk_chance = 30,
	-- Added stepheight
	stepheight = 1,
	walk_velocity = 2,
	run_velocity = 3,
	jump = true,
	drops = {
		{name = "default:wood", chance = 1, min = 1, max = 3},
		{name = "default:apple", chance = 2, min = 1, max = 2},
		{name = "default:axe_stone", chance = 5, min = 1, max = 1},
	},
	water_damage = 0,
	lava_damage = 2,
	light_damage = 0,
	follow = {"farming:bread", "mobs:meat", "default:diamond"},
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

		-- feed to heal npc
		if mobs:feed_tame(self, clicker, 8, true, true) then
			return
		end

		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()

		-- right clicking with gold lump drops random item from mobs.npc_drops
		if item:get_name() == "default:gold_lump" then

			if not minetest.setting_getbool("creative_mode") then
				item:take_item()
				clicker:set_wielded_item(item)
			end

			local pos = self.object:getpos()

			pos.y = pos.y + 0.5

			minetest.add_item(pos, {
				name = mobs.npc_drops[math.random(1, #mobs.npc_drops)]
			})

			minetest.chat_send_player(name, S("NPC dropped you an item for gold!"))

			return
		end
		
		-- See chat
		--show_chat_option(self.nametag, self, name, chat_options, "Nevermind") 

		-- capture npc with net or lasso
		mobs:capture_mob(self, clicker, 0, 5, 80, false, nil)

		-- by right-clicking owner can switch npc between follow and stand
		if self.owner and self.owner == name then

			if self.order == "follow" then
				self.order = "stand"

				minetest.chat_send_player(name, S("NPC stands still."))
			else
				self.order = "follow"

				minetest.chat_send_player(name, S("NPC will follow you."))
			end
		end

	end,
})

--mobs:register_spawn("mobs:npc", {"default:dirt_with_grass"}, 20, 0, 7000, 1, 31000)
--mobs:spawn_specific("mobs:npc", {"default:brick"}, {"air"}, 0, 15, 1, 1, 1, 0, 200, true)

--mobs:register_spawn("mobs:npc", {"mg_villages:plotmarker"}, 20, 0, 1, 7000, 31000)
--mobs:spawn_specific("mobs:npc", {"mg_villages:plotmarker"}, {"air"}, 0, 15, 30, 1, 100, 0, 200, true)

minetest.register_abm({
	label = "NPC spawning",
	nodenames = {"mg_villages:plotmarker"},
	neighbors = {"air"},
	interval = 30,
	chance = 25,
	catch_up = false,

	action = function(pos, node, active_object_count, active_object_count_wider)
		if active_object_count_wider > 20 then
			return
		end
		minetest.log("Spawning NPC on: "..dump(pos.x)..", "..dump(pos.y + 1)..", "..dump(pos.z))
		minetest.log("Active Object count: "..dump(active_object_count))
		minetest.log("Wider object count: "..dump(active_object_count_wider))
		pos.y = pos.y + 1
		local mob = minetest.add_entity(pos, "mobs_npc:npc")
		local ent = mob:get_luaentity()

		if not ent then
			mob:remove()
			return
		end
	end
})


mobs:register_egg("mobs_npc:npc", S("Npc"), "default_brick.png", 1)

-- compatibility
mobs:alias_mob("mobs:npc", "mobs_npc:npc")
