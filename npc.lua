
local S = mobs.intllib

-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 
npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"
npc.ITEM_GIFT_EFFECT = 2.5
npc.RELATIONSHIP_PHASE = {}
-- Define phases
npc.RELATIONSHIP_PHASE["phase1"] = {limit = 10}
npc.RELATIONSHIP_PHASE["phase2"] = {limit = 25}
npc.RELATIONSHIP_PHASE["phase3"] = {limit = 45}
npc.RELATIONSHIP_PHASE["phase4"] = {limit = 70}
npc.RELATIONSHIP_PHASE["phase5"] = {limit = 100}

npc.FAVORITE_ITEMS = {
  female = {},
  male = {}
}
-- Define items by phase
-- Female
npc.FAVORITE_ITEMS.female["phase1"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.female["phase2"] = {
  {item = "farming:cotton",        
   response = "This is going to be very helpful, thank you!"},
  {item = "wool:wool",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.female["phase3"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.female["phase4"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.female["phase5"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.female["phase6"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
-- Male
npc.FAVORITE_ITEMS.male["phase1"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.male["phase2"] = {
  {item = "farming:cotton",        
   response = "This is going to be very helpful, thank you!"},
  {item = "wool:wool",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.male["phase3"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.male["phase4"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.male["phase5"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}
npc.FAVORITE_ITEMS.male["phase6"] = {
  {item = "default:apple",        
   response = "You always know what I want to eat honey... thanks!"},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks..."}
}

-- Disliked items
npc.DISLIKED_ITEMS = {
  female = {
    {item = "default:stone",        
     response = "Stone, oh... why do you give me this?"},
    {item = "default:cobble",
     response = "Cobblestone? No, no, why?"}
  },
  male = {
    {item = "default:stone",        
     response = "Bah! Stone? I don't need this thing!"},
    {item = "default:cobble",
     response = "Cobblestone!? Wow, you sure think a lot before giving a gift..."}
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

-- Function to get relationship phase
function npc.get_relationship_phase(points)
	if points > npc.RELATIONSHIP_PHASE["phase5"].limit then
    return "phase6"
  elseif points > npc.RELATIONSHIP_PHASE["phase4"].limit then
    return "phase5"
  elseif points > npc.RELATIONSHIP_PHASE["phase3"].limit then
    return "phase4"
  elseif points > npc.RELATIONSHIP_PHASE["phase2"].limit then
    return "phase3"
  elseif points > npc.RELATIONSHIP_PHASE["phase1"].limit then
    return "phase2"
  else
    return "phase1"
  end
end

-- Returns the response message for a given item
function npc.get_response_for_favorite_item(item_name, sex, phase)
  local items = npc.FAVORITE_ITEMS.female
  if sex == npc.MALE then
    items = npc.FAVORITE_ITEMS.male
  end

  for i = 1, #items[phase] do
    if items[phase][i].item == item_name then
      return items[phase][i].response
    end
  end
  return nil
end 

-- Returns the response message for a disliked item
function npc.get_response_for_disliked_item(item_name, sex)
  local items = npc.DISLIKED_ITEMS.female
  if sex == npc.MALE then
    items = npc.DISLIKED_ITEMS.male
  end

  for i = 1, #items do
    if items[i].item == item_name then
      return items[i].response
    end
  end
  return nil
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

-- This function selects two random items from the npc.favorite_items table
-- It checks for sex and phase for choosing the items
local function select_random_favorite_items(sex, phase)
  local result = {}
  local items = {}
  
  -- Filter sex
  if sex == npc.FEMALE then
    items = npc.FAVORITE_ITEMS.female
  else
    items = npc.FAVORITE_ITEMS.male
  end

  -- Select the phase
  items = items[phase]
  
  result.fav1 = items[math.random(1, #items)].item
  result.fav2 = items[math.random(1, #items)].item
  return result
end

-- This function selects two random items from the npc.disliked_items table
-- It checks for sex and phase for choosing the items
local function select_random_disliked_items(sex)
  local result = {}
  local items = {}
  
  -- Filter sex
  if sex == npc.FEMALE then
    items = npc.DISLIKED_ITEMS.female
  else
    items = npc.DISLIKED_ITEMS.male
  end

  result.dis1 = items[math.random(1, #items)].item
  result.dis2 = items[math.random(1, #items)].item
  return result
end

-- Creates a relationship with a given player or NPC
local function create_relationship(self, clicker_name)
  local count = #self.relationships
  self.relationships[count + 1] = {
    -- Player or NPC name with whom the relationship is with
    name = clicker_name,
    -- Relationship points
    points = 0,
    -- Relationship phase, used for items and for phrases
    phase = "phase1",
    -- How frequent can the NPC receive a gift
    gift_interval = 1,
    -- Current timer count since last gift
    gift_timer_value = 0,
    -- The amount of time without providing gift or talking that will decrease relationship points
    relationship_decrease_interval = 5,
    -- Current timer count for relationship decrease
    relationship_decrease_timer_value = 0
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
      local current_phase = self.relationships[i].phase
      self.relationships[i].phase = npc.get_relationship_phase(self.relationships[i].points)
      if current_phase ~= self.relationships[i].phase then
        self.gift_data.favorite_items = 
          select_random_favorite_items(self.sex, self.relationships[i].phase)
        return true
      end
      return false
    end
  end
  -- Relationship not found, huge error
  return nil
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

-- Checks if NPC can receive gifts
local function check_npc_can_receive_gift(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      return self.relationships[i].gift_timer_value >= self.relationships[i].gift_interval
    end
  end
  -- Not found
  return nil
end

-- Resets the gift timer
local function reset_gift_timer(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      self.relationships[i].gift_timer_value = 0
      return
    end
  end
end

-- Gifts functions
---------------------------------------------------------------------------------------
  
-- Displays message and hearts depending on relationship level
local function show_receive_gift_reaction(self, item_name, modifier, clicker_name, phase_change) 
  local points = get_relationship_points(self, clicker_name)
  
  local pos = self.object:getpos()  
  -- Positive modifier (favorite items) reactions
  if modifier >= 0 then
    local phase = npc.get_relationship_phase(points)
    if phase == "phase3" then
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 2, "heart.png")
    elseif phase == "phase4" then
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 4, "heart.png")
    elseif phase == "phase5" then
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 6, "heart.png")
    elseif phase == "phase6" then
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "heart.png")
    end
    if phase_change then
      local number_code = phase:byte(phase:len()) - 1
      phase = "phase"..string.char(number_code)
    end
    -- Send message
    local message_to_send = npc.get_response_for_favorite_item(item_name, self.sex, phase)
    minetest.chat_send_player(clicker_name, message_to_send)
  -- Disliked items reactions
  elseif modifier < 0 then
    effect({x = pos.x, y = pos.y + 1, z = pos.z}, 8, "smoke.png")
    local message_to_send = npc.get_response_for_disliked_item(item_name, self.sex)
    minetest.chat_send_player(clicker_name, message_to_send)
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
  
  -- Create relationship if it doesn't exists
  if check_relationship_exists(self, clicker_name) == false then
    create_relationship(self, clicker_name)
  end

  -- If NPC received a gift from this person, then reject any more gifts for now
  if check_npc_can_receive_gift(self, clicker_name) == false then
    minetest.chat_send_player(clicker_name, "Thanks, but I don't need anything for now")
    return false
  end
  
  -- If NPC is ready for marriage, do no accept anything else but the ring,
  -- and that with only a certain chance. The self.owner is to whom is married
  -- this NPC... he he.
  if get_relationship_points(self, clicker_name) >= npc.RELATIONSHIP_PHASE["phase5"].limit 
    and self.owner ~= clicker_name
    and item:get_name() ~= "advanced_npc:marriage_ring" then
    minetest.chat_send_player(clicker_name, 
      "Thank you my love, but I think that you have given me")
    minetest.chat_send_player(clicker_name, 
      "enough gifts for now. Maybe we should go a step further")
    -- Reset gift timer
    reset_gift_timer(self, clicker_name)
    return true
  elseif get_relationship_points(self, clicker_name) >= npc.RELATIONSHIP_PHASE["phase5"].limit 
    and item:get_name() == "advanced_npc:marriage_ring" then
    -- If the player/entity is offering a marriage ring, then NPC will accept with a 50%
    -- chance to marry the clicker
    local receive_chance = math.random(1, 10)
    -- Receive ring and get married
    if receive_chance < 6 then
      minetest.chat_send_player(clicker_name, 
        "Oh, oh you make me so happy! Yes! I will marry you!")
      -- Get ring
      item:take_item()
      clicker:set_wielded_item(item)
      -- TODO: Implement marriage event
      -- Show marriage reaction
      local pos = self.object:getpos()
      effect({x = pos.x, y = pos.y + 1, z = pos.z}, 20, "heart.png", 4)
      -- Give 100 points, so NPC is really happy on marriage
      update_relationship(self, clicker_name, 100)
      -- This sets the married state, for now. Hehe
      self.owner = clicker_name
    -- Reject ring for now
    else 
      minetest.chat_send_player(clicker_name, 
        "Dear, I feel the same as you. But maybe not yet...")
    
    end
    -- Reset gift timer
    reset_gift_timer(self, clicker_name)
    return true
  end
  -- Marriage gifts: except for disliked items, all product a 0.5 * npc.ITEM_GIFT_EFFECT
  -- Disliked items cause only a -1 point effect
  if get_relationship_points(self, clicker_name) >= npc.RELATIONSHIP_PHASE["phase5"].limit then
    local modifier = 0.5 * npc.ITEM_GIFT_EFFECT
    -- Check for disliked items
    if item:get_name() == self.gift_data.disliked_items.dis1 
      or item:get_name() == self.gift_data.disliked_items.dis2 then
      modifier = -1
    end
    
    update_relationship(self, clicker_name, modifier)
    show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, false)
    -- Reset gift timer
    reset_gift_timer(self, clicker_name)
    return true
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
  elseif item:get_name() == self.gift_data.disliked_items.dis1 then
    modifier = (-2) * npc.ITEM_GIFT_EFFECT
    show_reaction = true
  elseif item:get_name() == self.gift_data.disliked_items.dis2 then 
    modifier = (-1) * npc.ITEM_GIFT_EFFECT
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
  
  -- Update relationship status
  local is_phase_changed = update_relationship(self, clicker_name, modifier)

   -- Show NPC reaction to gift
  if show_reaction == true then
    show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, is_phase_changed)
  end
  
  minetest.log(dump(self))
  -- Reset gift timer
  reset_gift_timer(self, clicker_name)
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
	do_custom = function(self, dtime)
		-- Timer function for gifts
    for i = 1, #self.relationships do
      local relationship = self.relationships[i]
      -- Gift timer check
      if relationship.gift_timer_value < relationship.gift_interval then
        relationship.gift_timer_value = relationship.gift_timer_value + dtime
      -- Relationship decrease timer
      else
        if relationship.relationship_decrease_timer_value 
            < relationship.relationship_decrease_interval then
          relationship.relationship_decrease_timer_value = 
            relationship.relationship_decrease_timer_value + dtime
        else
          -- Check if married to decrease half
          if relationship.phase == "phase6" then
            -- Avoid going below the marriage phase limit
            if (relationship.points - 0.5) >= npc.RELATIONSHIP_PHASE["phase5"] then
              relationship.points = relationship.points - 0.5
            end
          else
            relationship.points = relationship.points - 1
          end
          relationship.relationship_decrease_timer_value = 0
          minetest.log(dump(self))
        end
      end
    end		
	end
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
    -- Choose favorite items. Choose phase1 per default
    favorite_items = select_random_favorite_items(ent.sex, "phase1"),
    -- Choose disliked items. Choose phase1 per default
    disliked_items = select_random_disliked_items(ent.sex),
  }
  
  -- Initialize relationships object
  ent.relationships = {}
  
  minetest.log(dump(ent))
  
  ent.object:set_properties(ent)
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
