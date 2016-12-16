-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 

local S = mobs.intllib

npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"

npc.INVENTORY_ITEM_MAX_STACK = 99

---------------------------------------------------------------------------------------
-- General functions
---------------------------------------------------------------------------------------
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
function npc.get_entity_wielded_item(entity)
  if entity:is_player() then
    return entity:get_wielded_item()
  end
end

---------------------------------------------------------------------------------------
-- Inventory functions
---------------------------------------------------------------------------------------
-- NPCs inventories are restrained to 16 slots.
-- Each slot can hold one item up to 99 count.

-- Utility function to get item name from a string
local function get_item_name(item_string)
  local i,j = string.find(item_string, " ")
  return item_string.sub(item_string, 1, i-1)
end

-- Utility function to get item count from a string
local function get_item_count(item_string)
  local i,j = string.find(item_string, " ")
  return tonumber(item_string.sub(item_string, i+1))
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
-- These function can be used to give items to other NPCs
-- given that the "self" variable can be any NPC
function npc.add_item_to_inventory(self, item_name, count)
  -- Check if NPC already has item
  local existing_item = npc.inventory_contains(self, item_name)
  if existing_item ~= nil and existing_item.item_string ~= nil then
    -- NPC already has item. Get count and see
    minetest.log("What is this? "..dump(existing_item))
    local existing_count = get_item_count(existing_item.item_string)
    if (existing_count + count) < npc.INVENTORY_ITEM_MAX_STACK then
      -- Set item here
      self.inventory[existing_item.slot] = 
        get_item_name(existing_item.item_string).." "..tostring(existing_count + count)
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
  local item_name = get_item_name(item_string)
  local item_count = get_item_count(item_string)
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
    local existing_count = get_item_count(existing_item.item_string)
    local new_count = existing_count
    if existing_count - count  < 0 then
      -- Remove item first
      self.inventory[existing_item.slot] = ""
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

-- Inventory functions for players
function npc.give_item_to_player(player, item_name, count)
  local player_name = npc.get_entity_name(player)
  local player_inv = minetest.get_inventory({type="player", name=player_name})
  local item = ItemStack(item_name.." "..count)
  player_inv:add_item("main", item)
end

function npc.check_item_to_player(player, item_name)
  local player_name = npc.get_entity_name(player)
  local player_inv = minetest.get_inventory({type="player", name=player_name})
  local main_list = player_inv:get_list("main")
  for i = 1, #main_list do
    if main_list[i]:get_name() == item_name then
      return main_list[i]
    end
  end
  -- Not found
  return nil
end

function npc.take_item_from_player(player, item_name, count)
  local player_name = npc.get_entity_name(player)
  local player_inv = minetest.get_inventory({type="player", name=player_name})
  local main_list = player_inv:get_list("main")
  for i = 1, #main_list do
    if main_list[i]:get_name() == item_name then
      main_list[i].take_item(count)
    end
  end
  -- Not found
  return nil
end

-- Chat functions
function npc.start_dialogue(self, clicker, show_married_dialogue)

  -- Call chat function as normal
  npc.dialogue.start_dialogue(self, clicker, show_married_dialogue)

  -- Check and update relationship if needed
  npc.relationships.dialogue_relationship_update(self, clicker)

end

---------------------------------------------------------------------------------------
-- Definitions
---------------------------------------------------------------------------------------
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
            if (relationship.points - 0.5) >= 
              npc.relationships.RELATIONSHIP_PHASE["phase5"].limit then
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

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------
-- These functions are used at spawn time to determine several
-- random attributes for the NPC in case they are not already
-- defined. On a later phase, pre-defining many of the NPC values
-- will be allowed.

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

-- Choose a maximum of two items that the NPC will have at spawn time
-- These items are chosen from the favorite items list.
local function choose_spawn_items(self)
  local number_of_items_to_add = math.random(1, 2)
  local number_of_items = #npc.FAVORITE_ITEMS[self.sex].phase1
  minetest.log("Number of items: "..dump(number_of_items))
  for i = 1, number_of_items_to_add do
    npc.add_item_to_inventory(
       self,
       npc.FAVORITE_ITEMS[self.sex].phase1[math.random(1, number_of_items)].item, 
       math.random(1,4)
      )
  end
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
    favorite_items = npc.relationships.select_random_favorite_items(ent.sex, "phase1"),
    -- Choose disliked items. Choose phase1 per default
    disliked_items = npc.relationships.select_random_disliked_items(ent.sex),
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

  -- Choose items to spawn with
  choose_spawn_items(ent)

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
    change_offers_timer_interval = 20
  }

  -- Initialize trading offers if NPC is casual trader
  if ent.trader_data.trader_status == npc.trade.CASUAL then
    ent.trader_data.buy_offers = {
      [1] = npc.trade.get_casual_trade_offer(ent, npc.trade.OFFER_BUY)
    }

    ent.trader_data.sell_offers = {
      [1] = npc.trade.get_casual_trade_offer(ent, npc.trade.OFFER_SELL)
    }
  end

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
	inventory_image = "marriage_ring.png",
})

-- Marriage ring craft recipe
minetest.register_craft({
	output = "advanced_npc:marriage_ring",
	recipe = { {"", "", ""},
             {"", "default:diamond", ""},
             {"", "default:gold_ingot", ""} },
})
