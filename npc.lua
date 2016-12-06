
local S = mobs.intllib

-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 
npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"
npc.ITEM_GIFT_EFFECT = 2.5
-- Expected values for these are 720 each respectively
npc.GIFT_TIMER_INTERVAL = 2
npc.RELATIONSHIP_DECREASE_TIMER_INTERVAL = 60
npc.RELATIONSHIP_PHASE = {}
-- Define phases
npc.RELATIONSHIP_PHASE["phase1"] = {limit = 10}
npc.RELATIONSHIP_PHASE["phase2"] = {limit = 25}
npc.RELATIONSHIP_PHASE["phase3"] = {limit = 45}
npc.RELATIONSHIP_PHASE["phase4"] = {limit = 70}
npc.RELATIONSHIP_PHASE["phase5"] = {limit = 100}

-- Married NPC dialogue definition
npc.MARRIED_NPC_DIALOGUE = {
  text = "Hi darling!",
  is_married_dialogue = true,
  responses = {
    [1] = {
      text = "Let's talk!",
      action_type = "function",
      response_id = 1,
      action = function(self, player)
        npc.start_dialogue(self, player, false)
      end
    },
    [2] = {
      text = "Honey, can you wait for me here?",
      action_type = "function",
      response_id = 2,
      action = function(self, player)
        self.order = "stand"
        minetest.chat_send_player(player:get_player_name(), S("Ok dear, I will wait here for you."))
      end
    },
    [3] = {
      text = "Come with me, please!",
      action_type = "function",
      response_id = 3,
      action = function(self, player)
        self.order = "follow"
        minetest.chat_send_player(player:get_player_name(), S("Ok, let's go!"))
      end
    }
  }
}

npc.INVENTORY_ITEM_MAX_STACK = 99

mobs.npc_drops = {
	"default:pick_steel", "mobs:meat", "default:sword_steel",
	"default:shovel_steel", "farming:bread", "bucket:bucket_water"
}


-- General functions
-- Gets name of player or NPC
function npc.get_entity_name(entity)
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

-- Inventory functions
-- NPCs inventories are restrained to 16 slots.
-- Each slot can hold one item up to 99 count.

-- Utility function to get item name from a string
local function get_item_name(item_string)
  return item_string.sub(item_string, 1, item_string.find(" "))
end

-- Utility function to get item count from a string
local function get_item_count(item_string)
  return tonumber(item_string.sub(item_string, item_string.find(" ")))
end

local function initialize_inventory()
  return {
    [1] = "",  [2] = "",  [3] = "",  [4] = "",
    [5] = "",  [6] = "",  [7] = "",  [8] = "",
    [9] = "",  [10] = "", [11] = "", [12] = "",
    [13] = "", [14] = "", [15] = "", [16] = "",
  }
end

-- Add an item to inventory. Returns true if add successful
function npc.add_item_to_inventory(self, item_name, count)
  -- Check if NPC already has item
  local existing_item = npc.inventory_contains(self, item_name)
  if existing_item.item_string ~= nil then
    -- NPC already has item. Get count and see
    local existing_count = get_item_count(existing_item.item_string)
    if (existing_count + count) < npc.INVENTORY_ITEM_MAX_STACK then
      -- Set item here
      self.inventory[existing_item.slot] = 
        get_item_name(existing_item.item_string).." "..tostring(existing_count + count)
        return true
    else
      --Find next free slot
      for i = 1, self.inventory do
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
    for i = 1, self.inventory do
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

-- Checks if an item is contained in the inventory. Returns
-- the item string or nil if not found
function npc.inventory_contains(self, item_name)
  for key,value in pairs(self.inventory) do
    if tostring(value).find(item_name) then
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
    local existing_count = get_item_count(existing_item.item_string)
    local new_count = existing_count
    if existing_count - count  < 0 then
      -- Remove item first
      self.inventory[existin_item.slot] = ""
      -- TODO: Support for retrieving from next stack. Too complicated
      -- and honestly might be unecessary.
      return item_name.." "..tostring(new_count)
    else
      new_count = existing_count - count
      self.inventory[existing_item.slot] = item_name.." "..new_count
      return item_name.." "..tostring(count)
    end
  else
    -- Not able to take item because not found
    return nil
  end
end

-- Function to get relationship phase
function npc.get_relationship_phase_by_points(points)
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

-- Gets the item hint for a favorite item
function npc.get_hint_for_favorite_item(item_name, sex, phase)
  for i = 1, #npc.FAVORITE_ITEMS[sex][phase] do
    if npc.FAVORITE_ITEMS[sex][phase][i].item == item_name then
      return npc.FAVORITE_ITEMS[sex][phase][i].hint
    end
  end
  return nil
end

-- Gets the item hint for a disliked item
function npc.get_hint_for_disliked_item(item_name, sex)
  for i = 1, #npc.DISLIKED_ITEMS[sex] do
    if npc.DISLIKED_ITEMS[sex][i].item == item_name then
      return npc.DISLIKED_ITEMS[sex][i].hint
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
-- It checks for sex for choosing the items. They stay the same for all
-- phases
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
    gift_interval = npc.GIFT_TIMER_INTERVAL,
    -- Current timer count since last gift
    gift_timer_value = 0,
    -- The amount of time without providing gift or talking that will decrease relationship points
    relationship_decrease_interval = npc.RELATIONSHIP_DECREASE_TIMER_INTERVAL,
    -- Current timer count for relationship decrease
    relationship_decrease_timer_value = 0,
    -- Current timer count since last time player talked to NPC
    talk_timer_value = 0
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
      self.relationships[i].phase = npc.get_relationship_phase_by_points(self.relationships[i].points)
      if current_phase ~= self.relationships[i].phase then
        -- Re-select favorite items per new phase
        self.gift_data.favorite_items = 
          select_random_favorite_items(self.sex, self.relationships[i].phase)
        -- Re-select dialogues per new
        self.dialogues =
          npc.dialogue.select_random_dialogues_for_npc(self.sex, 
                                                       self.relationships[i].phase,
                                                       self.gift_data.favorite_items,
                                                       self.gift_data.disliked_items)
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

-- Returns the relationship phase given the name of the player
function npc.get_relationship_phase(self, clicker_name)
  for i = 1, #self.relationships do
    if clicker_name == self.relationships[i].name then
      return self.relationships[i].phase
    end
  end
  return nil
end

-- Checks if NPC can receive gifts
local function check_npc_can_receive_gift(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      -- Checks avoid married NPC to receive from others
      if self.is_married_to == nil 
        or (self.is_married ~= nil and self.is_married_to == clicker_name) then 
        return self.relationships[i].gift_timer_value >= self.relationships[i].gift_interval
      else
        return false
      end
    end
  end
  -- Not found
  return nil
end

-- Checks if relationship can be updated by talking
local function check_relationship_by_talk_timer_ready(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      return self.relationships[i].talk_timer_value >= self.relationships[i].gift_interval
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
      self.relationships[i].relationship_decrease_timer_value = 0
      return
    end
  end
end

-- Resets the talk timer
local function reset_talk_timer(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      self.relationships[i].talk_timer_value = 0
      return
    end
  end
end

-- Resets the relationshop decrease timer
local function reset_relationship_decrease_timer(self, clicker_name)
  for i = 1, #self.relationships do
    if self.relationships[i].name == clicker_name then
      self.relationships[i].relationship_decrease_timer_value = 0
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
    local phase = npc.get_relationship_phase_by_points(points)
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
    -- TODO: There might be an error with getting the message...
    minetest.log("Item_name: "..dump(item_name)..", sex: "..dump(self.sex)..", phase: "..dump(phase))
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
  local clicker_name = npc.get_entity_name(clicker)
  
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
      show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, false)
    elseif item:get_name() == self.gift_data.favorite_items.fav1 
      or item:get_name() == self.gift_data.favorite_items.fav2 then
      -- Favorite item reaction
      show_receive_gift_reaction(self, item:get_name(), modifier, clicker_name, false)
    else
      -- Neutral item reaction 
      minetest.chat_send_player(clicker_name, "Thank you honey!")
    end
    -- Take item
    item:take_item()
    clicker:set_wielded_item(item)
    -- Update relationship
    update_relationship(self, clicker_name, modifier)
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

-- Relationships are slowly increased by talking, increases by +0.2.
-- Talking to married NPC increases relationship by +1 
-- TODO: This needs a timer as the gift timer. NPC will talk anyways
-- but relationship will not increase.
local function dialogue_relationship_update(self, clicker)
  -- Get clicker name
  local clicker_name = npc.get_entity_name(clicker)

  -- Check if relationship can be updated via talk
  if check_relationship_by_talk_timer_ready(self, clicker_name) == false then
    return
  end
  
  -- Create relationship if it doesn't exists
  if check_relationship_exists(self, clicker_name) == false then
    create_relationship(self, clicker_name)
  end

  local modifier = 0.2
  if self.is_married_to ~= nil and clicker_name == self.is_married_to then
    modifier = 1
  end
  -- Update relationship
  update_relationship(self, clicker_name, modifier)

  -- Resert timers
  reset_talk_timer(self, clicker_name)
  reset_relationship_decrease_timer(self, clicker_name)
end

-- Chat functions
function npc.start_dialogue(self, clicker, show_married_dialogue)

  -- Call chat function as normal
  npc.dialogue.start_dialogue(self, clicker, show_married_dialogue)

  -- Check and update relationship if needed
  dialogue_relationship_update(self, clicker)

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
    
    -- Receive gift or start chat. If player has no item in hand
    -- then it is going to start chat directly
    if self.can_have_relationship and item:to_table() ~= nil then
      -- Get item name
      local item = minetest.registered_items[item:get_name()]
      local item_name = item.description

      -- Show dialogue to confirm that player is giving item as gift
      npc.dialogue.show_yes_no_dialogue(
        "Do you want to give "..item_name.." to "..self.nametag.."?",
        npc.dialogue.POSITIVE_GIFT_ANSWER_PREFIX..item_name,
        function()
          receive_gift(self, clicker)
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
            if (relationship.points - 0.5) >= npc.RELATIONSHIP_PHASE["phase5"].limit then
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

-- Choose whether NPC can have relationships. Only 30% of NPCs cannot have relationships
local function can_have_relationships()
  local chance = math.random(1,10)
  return chance > 3
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
  
  -- Flag that determines if NPC can have a relationship
  ent.can_have_relationship = can_have_relationships()

  -- Initialize relationships object
  ent.relationships = {}

  -- Determines if NPC is married or not
  ent.is_married_to = nil

  -- Initialize dialogues
  ent.dialogues = npc.dialogue.select_random_dialogues_for_npc(ent.sex, 
                                                               "phase1",
                                                               ent.gift_data.favorite_items,
                                                               ent.gift_data.disliked_items)

  -- Declare NPC inventory
  ent.inventory = initialize_inventory()

  ent.trader_data = {
    -- Type of trader
    trader_status = npc.trade.get_random_trade_status()
    -- Items to buy
    items_to_buy = {},
    -- Items to sell
    items_to_sell = {},
    -- Items to buy change timer
    change_items_to_buy_timer_value = 0,
    -- Items to buy change timer interval
    change_items_to_buy_timer_interval = 20
  }

  -- Initialize items to buy and items to sell depending on trader status
  

  
  minetest.log(dump(ent))
  
  -- Refreshes entity
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
