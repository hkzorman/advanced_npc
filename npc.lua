
local S = mobs.intllib

-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 
npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"
npc.ITEM_GIFT_EFFECT = 2.5
npc.RELATIONSHIP_PHASE1_LIMIT = 10
npc.RELATIONSHIP_PHASE2_LIMIT = 25
npc.RELATIONSHIP_PHASE3_LIMIT = 45
npc.RELATIONSHIP_PHASE4_LIMIT = 70
npc.RELATIONSHIP_PHASE5_LIMIT = 100

npc.FAVORITE_ITEMS = {
  female = {
      "default:apple",
      "farming:bread",
      "mobs:meat",
      "default:pick_steel",
      "default:shovel_steel",
      "default:sword_steel"
  },
  male = {
      "default:apple",
      "farming:bread",
      "mobs:meat",
      "default:pick_steel",
      "default:shovel_steel",
      "default:sword_steel"
  }
}

-- TODO: Complete responses for female and males, both adult and child
npc.GIFT_RESPONSES = {
  female = {
      {
        phase1 = "Thank you!",
        phase2 = "It is very appreciated! Thanks!",
        phase3 = "Thank you! You definetely are special...",
        phase4 = "Awww, you are so great!",
        phase5 = "Oh, so cute! Thank you! I love you!",
        phase6 = "Thank you my dear! You are the greatest husband!"
      },
      {
        phase1 = "Thank you!",
        phase2 = "It is very appreciated! Thanks!",
        phase3 = "Thank you! You definetely are special...",
        phase4 = "Awww, you are so great!",
        phase5 = "Oh, so cute! Thank you! I love you!",
        phase6 = "Thank you my dear! You are the greatest husband!"
      },
      {
        phase1 = "Thank you!",
        phase2 = "It is very appreciated! Thanks!",
        phase3 = "Thank you! You definetely are special...",
        phase4 = "Awww, you are so great!",
        phase5 = "Oh, so cute! Thank you! I love you!",
        phase6 = "Thank you my dear! You are the greatest husband!"
      },
      {
        phase1 = "Thank you!",
        phase2 = "It is very appreciated! Thanks!",
        phase3 = "Thank you! You definetely are special...",
        phase4 = "Awww, you are so great!",
        phase5 = "Oh, so cute! Thank you! I love you!",
        phase6 = "Thank you my dear! You are the greatest husband!"
      },
      {
        phase1 = "Thank you!",
        phase2 = "It is very appreciated! Thanks!",
        phase3 = "Thank you! You definetely are special...",
        phase4 = "Awww, you are so great!",
        phase5 = "Oh, so cute! Thank you! I love you!",
        phase6 = "Thank you my dear! You are the greatest husband!"
      }
  },
  male = {
    
  }
}

mobs.npc_drops = {
	"default:pick_steel", "mobs:meat", "default:sword_steel",
	"default:shovel_steel", "farming:bread", "bucket:bucket_water"
}


-- General functions
-- Gets name of player or NPC
local function get_entity_name(entity)
  if entity:is_player() then
    return entity:get_player_name()
  else
    return entity:get_luaentity().nametag
  end
end

-- Returns the item "wielded" by player or NPC
-- TODO: Implement NPC
local function get_entity_wielded_item(entity)
  if entity:is_player() then
    return entity:get_wielded_item()
  end
end


-- Functions on right click
---------------------------------------------------------------------------------------
-- Gift and relationship system
---------------------------------------------------------------------------------------
-- Each NPCs has 2 favorite and 2 disliked items. These items are chosen at spawn
-- time and will be re-chosen when the age changes (from child to adult, for example).
-- The items are chosen from the npc.FAVORITE_ITEMS table, and depends on sex and age.
-- A player, via right-click, or another NPC, can gift an item to a NPC. In the case
-- of the player, the player will give one of the currently wielded item. Gifts can be
-- given only once per some time period, the NPC will reject the given item if still 
-- the period isn't over.
-- If the NPC is neutral on the item (meanining it's neither favorite or disliked), it 
-- is possible it will not accept it, and the relationship the giver has with the NPC
-- will be unchanged.
-- In the other hand, if the item given its a favorite, the relationship points the NPC
-- has with giver will increase by a given amount, depending on favoriteness. Favorite 1
-- will increase the relationship by 2 * npc.ITEM_GIFT_EFFECT, and favorite 2 only by
-- npc.ITEM_GIFT_EFFECT. Similarly, if the item given is a disliked item, the NPC will
-- not take it, and its relationship points with the giver will decrease by 2 or 1 times
-- npc.ITEM_GIFT_EFFECT.

-- Relationship functions

---------------------------------------------------------------------------------------
-- Creates a relationship with a given player or NPC
local function create_relationship(self, clicker_name)
  local count = #self.relationships
  self.relationships[count + 1] = {
    name = clicker_name,
    points = 0
  }
end

-- Returns a relationship points
local function get_relationship_points(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      return self.relationships[i].points
    end
  end
  return nil
end

-- Updates relationship with given points
local function update_relationship(self, clicker_name, modifier)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      self.relationships[i].points = self.relationships[i].points + modifier
      return
    end
  end
end

-- Checks if a relationship with given player or NPC exists
local function check_relationship_exists(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      return true
    end
  end
  return false
end

-- Gifts functions
---------------------------------------------------------------------------------------

-- This function selects two random items from the npc.favorite_items table
-- It checks both for age and for sex for choosing the items
local function select_random_favorite_items(sex)
  local result = {}
  local items = {}
  
  -- Filter sex
  if sex == npc.FEMALE then
    items = npc.FAVORITE_ITEMS.female
  else
    items = npc.FAVORITE_ITEMS.male
  end
  
  result.fav1 = items[math.random(1, #items)]
  result.fav2 = items[math.random(1, #items)]
  return result
end

-- Displays message and hearts depending on relationship level
local function show_receive_gift_reaction(self, clicker_name) 
  local points = get_relationship_points(self, clicker_name)
  
  local chat_messages = {}
  if self.sex == npc.FEMALE then
      chat_messages = npc.GIFT_RESPONSES.female[1]
      minetest.log(dump(chat_messages))
  end
  
  local pos = self.object:getpos()
  local message_to_send = ""
  
  -- Positive relationship reactions
  if points >= 0 then
    if points < npc.RELATIONSHIP_PHASE1_LIMIT then
      message_to_send = chat_messages.phase1
    elseif points < npc.RELATIONSHIP_PHASE2_LIMIT then
      message_to_send = chat_messages.phase2
    elseif points < npc.RELATIONSHIP_PHASE3_LIMIT then
      message_to_send = chat_messages.phase3
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 2, "heart.png")
    elseif points < npc.RELATIONSHIP_PHASE4_LIMIT then
      message_to_send = chat_messages.phase4
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 4, "heart.png")
    elseif points < npc.RELATIONSHIP_PHASE5_LIMIT then
      message_to_send = chat_messages.phase5
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 6, "heart.png")
    -- This will show when players are married
    elseif points > npc.RELATIONSHIP_PHASE5_LIMIT then
      message_to_send = chat_messages.phase6
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "heart.png")
    end
    -- Send message
    minetest.chat_send_player(clicker_name, message_to_send)
  -- Relationship is in negative state
  elseif points < 0 then
    
  end
  
end

-- Receive gift function; applies relationship points as explained above
-- Also, creates a relationship object if not present
local function receive_gift(self, clicker)  
  -- Return if clicker is not offering an item
  local item = get_entity_wielded_item(clicker)
  if item:get_name() == "" then return false end
  
  -- Get clicker name
  local clicker_name = get_entity_name(clicker)
  
  -- If NPC received a gift, then reject any more gifts for now
  if self.gift_data.gift_timer_value < self.gift_data.gift_interval then
    minetest.chat_send_player(clicker_name, "Thanks, but I don't need anything for now")
    return false
  end
  
  -- Create relationship if it doesn't exists
  if check_relationship_exists(self, clicker_name) == false then
    create_relationship(self, clicker_name)
  end
  
  -- If NPC is ready for marriage, do no accept anything else but the ring,
  -- and that with only a certain chance. The self.owner is to whom is married
  -- this NPC... he he.
  minetest.log(get_relationship_points(self, clicker_name))
  if get_relationship_points(self, clicker_name) >= npc.RELATIONSHIP_PHASE5_LIMIT 
    and self.owner ~= clicker_name
    and item:get_name() ~= "advanced_npc:marriage_ring" then
    minetest.chat_send_player(clicker_name, "Thank you my love, but I think that you have given me")
    minetest.chat_send_player(clicker_name, "enough gifts for now. Maybe we should go a step further")
    self.gift_data.gift_timer_value = 0
    return true
  elseif get_relationship_points(self, clicker_name) >= npc.RELATIONSHIP_PHASE5_LIMIT 
    and item:get_name() == "advanced_npc:marriage_ring" then
    -- If the player/entity is offering a marriage ring, then NPC will accept with a 50%
    -- chance to marry the clicker
    local receive_chance = math.random(1, 10)
    -- Receive ring and get married
    if receive_chance < 6 then
      minetest.chat_send_player(clicker_name, "Oh, oh you make me so happy! Yes! I will marry you!")
      -- Get ring
      item:take_item()
      clicker:set_wielded_item(item)
      -- Show marriage reaction
      local pos = self.object:getpos()
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 20, "heart.png", 4)
      -- Give 100 points, so NPC is really happy on marriage
      update_relationship(self, clicker_name, 100)
      -- This sets the married state, for now. Hehe
      self.owner = clicker_name
      self.gift_data.gift_timer_value = 0
      return true
    -- Reject ring for now
    else 
      minetest.chat_send_player(clicker_name, "Dear, I feel the same as you. But maybe not yet...")
      self.gift_data.gift_timer_value = 0
      return true
    end
  end
  
  -- Modifies relationship depending on given item
  local modifier = 0
  local take = true
  local show_reaction = false
  
  if item:get_name() == self.gift_data.favorite_items.fav1 then
    modifier = 2 * npc.ITEM_GIFT_EFFECT
    show_reaction = true
  elseif item:get_name() == self.gift_data.favorite_items.fav2 then 
    modifier = npc.ITEM_GIFT_EFFECT
    show_reaction = true
  else
    -- If item is not a favorite or a dislike, then receive chance
    -- if 70%
      local receive_chance = math.random(1,10)
      if receive_chance < 7 then
        minetest.chat_send_player(clicker_name, "Thanks. I will find some use for this.")
      else
        minetest.chat_send_player(clicker_name, "Thank you, but no, I have no use for this.")
        take = false
      end
      show_reaction = false
  end
  
  -- Take item if NPC accepted it
  if take == true then
    item:take_item()
    clicker:set_wielded_item(item)
  end
  
  -- Show NPC reaction to gift
  if show_reaction == true then
    show_receive_gift_reaction(self, clicker_name)
  end
  
  -- Update relationship status
  update_relationship(self, clicker_name, modifier)
  
  minetest.log(dump(self))
  self.gift_data.gift_timer_value = 0
  return true  
end

-- Chat functions

local function start_chat(self, clicker)
  local name = get_entity_name(clicker)
  -- Married player can tell NPC to follow or to stay at a given place
  -- TODO: Improve this. There should be a dialogue box for this
  if self.owner and self.owner == name then
		if self.order == "follow" then
			self.order = "stand"
			minetest.chat_send_player(name, S("Ok dear, I will wait here for you."))
		else
			self.order = "follow"
			minetest.chat_send_player(name, S("Let's go honey!"))
		end
	end
end


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
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "character.b3d",
	drawtype = "front",
	textures = {
		{"mobs_npc_male1.png"},
		{"mobs_npc_female1.png"}, -- female by nuttmeg20
	},
	child_texture = {
		{"mobs_npc_baby_male1.png"}, -- derpy baby by AmirDerAssassine
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

		local item = clicker:get_wielded_item()
		local name = clicker:get_player_name()
    
    minetest.log(dump(self))
    
    -- Receive gift or start chat
    if receive_gift(self, clicker) == false then
        start_chat(self, clicker)
    end  

	end,
})

-- This function checks for "female" text on the texture name
local function is_female_texture(textures)
  for i = 1, #textures do
    if string.find(textures[i], "female") ~= nil then
      return true
    end
  end
  return false
end

local function npc_spawn(self, pos)
  minetest.log("Spawning new NPC:")
  local ent = self:get_luaentity()
  ent.nametag = "Kio"
  
  -- Determine sex based on textures
  if (is_female_texture(ent.base_texture)) then
    ent.sex = npc.FEMALE
  else
    ent.sex = npc.MALE
  end
  
  -- Initialize all gift data
  ent.gift_data = {
    -- Choose favorite items
    favorite_items = select_random_favorite_items(ent.sex),
    -- How frequent can the NPC receive a gift
    gift_interval = 10,
    -- Current timer count since last gift
    gift_timer_value = 0
  }
  
  -- Timer function for gifts
  ent.on_step = function(self, dtime)
    if self.gift_data.gift_timer_value < self.gift_data.gift_interval then
      self.gift_data.gift_timer_value = self.gift_data.gift_timer_value + dtime
      minetest.log(dump(self.gift_data.gift_timer_value))
    end
  end
  
  -- Initialize relationships object
  ent.relationships = {}
  
  minetest.log(dump(ent))
end

-- Spawn
mobs:spawn({
	name = "advanced_npc:npc",
	nodes = {"default:stone"},
	min_light = 3,
	active_object_count = 1,
  interval = 5,
  chance = 1,
	--max_height = 0,
	on_spawn = npc_spawn,
})

mobs:register_egg("advanced_npc:npc", S("Npc"), "default_brick.png", 1)

-- compatibility
mobs:alias_mob("mobs:npc", "advanced_npc:npc")

-- Marriage ring
minetest.register_craftitem("advanced_npc:marriage_ring", {
	description = S("Marriage Ring"),
	inventory_image = "diamond_ring.png",
})

-- Marriage ring craft recipe
minetest.register_craft({
	output = "advanced_npc:marriage_ring",
	recipe = { {"", "", ""},
             {"", "default:diamond", ""},
             {"", "default:gold_ingot", ""} },
})
