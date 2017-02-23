-- Advanced NPC by Zorman2000
-- Based on original NPC by Tenplus1 

local S = mobs.intllib

npc = {}

-- Constants
npc.FEMALE = "female"
npc.MALE = "male"

npc.INVENTORY_ITEM_MAX_STACK = 99

npc.ANIMATION_STAND_START = 0
npc.ANIMATION_STAND_END = 79
npc.ANIMATION_SIT_START = 81
npc.ANIMATION_SIT_END = 160
npc.ANIMATION_LAY_START = 162
npc.ANIMATION_LAY_END = 166
npc.ANIMATION_WALK_START = 168
npc.ANIMATION_WALK_END = 187

npc.direction = {
  north = 0,
  east  = 1,
  south = 2,
  west  = 3
}

npc.action_state = {
  none = 0,
  executing = 1,
  interrupted = 2
}

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
function npc.get_item_name(item_string)
  return ItemStack(item_string):get_name()
end

-- Utility function to get item count from a string
function npc.get_item_count(item_string)
  return ItemStack(item_string):get_count()
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
    local existing_count = npc.get_item_count(existing_item.item_string)
    if (existing_count + count) < npc.INVENTORY_ITEM_MAX_STACK then
      -- Set item here
      self.inventory[existing_item.slot] = 
        npc.get_item_name(existing_item.item_string).." "..tostring(existing_count + count)
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
  local item_name = npc.get_item_name(item_string)
  local item_count = npc.get_item_count(item_string)
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
    local existing_count = npc.get_item_count(existing_item.item_string)
    local new_count = existing_count
    if existing_count - count  < 0 then
      -- Remove item first
      self.inventory[existing_item.slot] = ""
      -- TODO: Support for retrieving from next stack. Too complicated
      -- and honestly might be unecessary.
      return item_name.." "..tostring(new_count)
    else
      new_count = existing_count - count
      if new_count == 0 then
        self.inventory[existing_item.slot] = ""
      else
        self.inventory[existing_item.slot] = item_name.." "..new_count
      end
      return item_name.." "..tostring(count)
    end
  else
    -- Not able to take item because not found
    return nil
  end
end

-- Same take method but with itemstring for convenience
function npc.take_item_from_inventory_itemstring(self, item_string)
  local item_name = npc.get_item_name(item_string)
  local item_count = npc.get_item_count(item_string)
  npc.take_item_from_inventory(self, item_name, item_count)
end

---------------------------------------------------------------------------------------
-- Flag functionality
---------------------------------------------------------------------------------------
-- TODO: Consider removing them as they are pretty simple and straight forward.
-- Generic variables or function that help drive some functionality for the NPC.
function npc.add_flag(self, flag_name, value)
  self.flags[flag_name] = value
end

function npc.update_flag(self, flag_name, value)
  self.flags[flag_name] = value
end

function npc.get_flag(self, flag_name)
  return self.flags[flag_name]
end

---------------------------------------------------------------------------------------
-- Dialogue functionality
---------------------------------------------------------------------------------------
function npc.start_dialogue(self, clicker, show_married_dialogue)

  -- Call dialogue function as normal
  npc.dialogue.start_dialogue(self, clicker, show_married_dialogue)

  -- Check and update relationship if needed
  npc.relationships.dialogue_relationship_update(self, clicker)

end

---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- This function adds a function to the action queue.
-- Actions should be added in strict order for tasks to work as expected.
function npc.add_action(self, action, arguments)
  local action_entry = {action=action, args=arguments, is_task=false}
  table.insert(self.actions.queue, action_entry)
end

-- This function adds task actions in-place, as opposed to
-- at the end of the queue. This allows for continued order
function npc.add_task(self, task, args)
  local action_entry = {action=task, args=args, is_task=true}
  table.insert(self.actions.queue, action_entry)
end

-- This function removes the first action in the action queue
-- and then executes it
function npc.execute_action(self)
  -- Check if an action was interrupted
  if self.actions.current_action_state == npc.action_state.interrupted then
    minetest.log("Inserting interrupted action: ")
    -- Insert into queue the interrupted action
    table.insert(self.actions.queue, 1, self.actions.state_before_lock.interrupted_action)
    -- Clear the action
    self.actions.state_before_lock.interrupted_action = {}
    -- Clear the position
    self.actions.state_before_lock.pos = {}
  end
  local result = nil
  if table.getn(self.actions.queue) == 0 then
    -- Set state to none
    self.actions.current_action_state = npc.action_state.none
    -- Keep state the same if there are no more actions in actions queue
    return self.freeze
  end
  local action_obj = self.actions.queue[1]
  -- If the entry is a task, then push all this new operations in
  -- stack fashion
  if action_obj.is_task == true then
    minetest.log("Executing task")
    -- Backup current queue
    local backup_queue = self.actions.queue
    -- Remove this "task" action from queue
    table.remove(self.actions.queue, 1)
    -- Clear queue
    self.actions.queue = {}
    -- Now, execute the task with its arguments
    action_obj.action(self, action_obj.args)
    -- After all new actions has been added by task, add the previously
    -- queued actions back
    for i = 1, #backup_queue do
      table.insert(self.actions.queue, backup_queue[i])
    end
  else
    minetest.log("Executing action")
    -- Store the action that is being executed
    self.actions.state_before_lock.interrupted_action = action_obj
    -- Store current position
    self.actions.state_before_lock.pos = self.object:getpos()
    -- Execute action as normal
    result = action_obj.action(self, action_obj.args)
    -- Remove task
    table.remove(self.actions.queue, 1)
    -- Set state
    self.actions.current_action_state = npc.action_state.executing
  end
  return result
end

function npc.lock_actions(self)

  -- Avoid re-locking if already locked
  if self.actions.action_timer_lock == true then
    return
  end

  local pos = self.object:getpos()

  if self.freeze == false then
    -- Round current pos to avoid the NPC being stopped on positions
    -- where later on can't walk to the correct positions
    -- Choose which position is to be taken as start position
    if self.actions.state_before_lock.pos ~= {} then
      pos = vector.round(self.actions.state_before_lock.pos)
    else
      pos = vector.round(self.object:getpos())
    end
    pos.y = self.object:getpos().y
  end
  -- Stop NPC
  npc.actions.stand(self, {pos=pos})
  -- Avoid all timer execution
  self.actions.action_timer_lock = true
  -- Reset timer so that it has some time after interaction is done
  self.actions.action_timer = 0
  -- Check if there are is an action executing
  if self.actions.current_action_state == npc.action_state.executing 
    and self.freeze == false then
    -- Store the current action state
    self.actions.state_before_lock.action_state = self.actions.current_action_state
    -- Set current action state to interrupted
    self.actions.current_action_state = npc.action_state.interrupted
  end
  -- Store the current freeze variable
  self.actions.state_before_lock.freeze = self.freeze
  -- Freeze mobs_redo API
  self.freeze = false

  minetest.log("Locking")
end

function npc.unlock_actions(self)
  -- Allow timers to execute
  self.actions.action_timer_lock = false
  -- Restore the value of self.freeze
  self.freeze = self.actions.state_before_lock.freeze
  
  if table.getn(self.actions.queue) == 0 then
    -- Allow mobs_redo API to execute since action queue is empty
    self.freeze = true
  end

  minetest.log("Unlocked")
end

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
  
  for i = 1, number_of_items_to_add do
    npc.add_item_to_inventory(
       self,
       npc.FAVORITE_ITEMS[self.sex].phase1[math.random(1, number_of_items)].item, 
       math.random(1,5)
      )
  end
  -- Add currency to the items spawned with. Will add 5-10 tier 3
  -- currency items
  local currency_item_count = math.random(5, 10)
  npc.add_item_to_inventory(self, npc.trade.prices.currency.tier3.string, currency_item_count)

  -- For test
  npc.add_item_to_inventory(self, "default:tree", 10)
  npc.add_item_to_inventory(self, "default:cobble", 10)
  npc.add_item_to_inventory(self, "default:diamond", 2)
  npc.add_item_to_inventory(self, "default:mese_crystal", 2)
  npc.add_item_to_inventory(self, "flowers:rose", 2)
  npc.add_item_to_inventory(self, "advanced_npc:marriage_ring", 2)
  npc.add_item_to_inventory(self, "flowers:geranium", 2)
  npc.add_item_to_inventory(self, "mobs:meat", 2)
  npc.add_item_to_inventory(self, "mobs:leather", 2)
  npc.add_item_to_inventory(self, "default:sword_stone", 2)
  npc.add_item_to_inventory(self, "default:shovel_stone", 2)
  npc.add_item_to_inventory(self, "default:axe_stone", 2)

  minetest.log("Initial inventory: "..dump(self.inventory))
end

-- -- Creates new single buy and sell offers for NPCs that
-- -- trade casually.
-- local function select_casual_trade_offers(self)
--   self.trader_data.buy_offers = {
--     [1] = npc.trade.get_casual_trade_offer(self, npc.trade.OFFER_BUY)
--   }
--   self.trader_data.sell_offers = {
--     [1] = npc.trade.get_casual_trade_offer(self, npc.trade.OFFER_SELL)
--   }
-- end

-- Spawn function. Initializes all variables that the
-- NPC will have and choose random, starting values
local function npc_spawn(self, pos)
  minetest.log("Spawning new NPC:")

  -- Get Lua Entity
  local ent = self:get_luaentity()

  -- Avoid NPC to be removed by mobs_redo API
  ent.remove_ok = false

  -- Set name
  ent.nametag = "Kio"

  -- Set ID
  ent.npc_id = tostring(math.random(1000, 9999))..":"..ent.nametag
  
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

  -- Flags: generic booleans or functions that help drive functionality
  ent.flags = {}

  -- Declare trade data
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
    change_offers_timer_interval = 60,
    -- Trading list: a list of item names the trader is expected to trade in.
    -- It is mostly related to its occupation.
    -- If empty, the NPC will revert to casual trading
    -- If not, it will try to sell those that it have, and buy the ones it not.
    trade_list = {
      sell = {},
      buy = {},
      both = {}
    },
    -- Custom trade allows to specify more than one payment
    -- and a custom prompt (instead of the usual buy or sell prompts)
    custom_trades = {}
  }

  -- Initialize trading offers for NPC
  --npc.trade.generate_trade_offers_by_status(ent)
  -- if ent.trader_data.trader_status == npc.trade.CASUAL then
  --   select_casual_trade_offers(ent)
  -- end

  -- Actions data
  ent.actions = {
    -- The queue is a queue of actions to be performed on each interval
    queue = {},
    -- Current value of the action timer
    action_timer = 0,
    -- Determines the interval for each action in the action queue
    -- Default is 1. This can be changed via actions
    action_interval = 1,
    -- Avoid the execution of the action timer
    action_timer_lock = false,
    -- Defines the state of the current action
    current_action_state = npc.action_state.none,
    -- Store information about action on state before lock
    state_before_lock = {
      -- State of the mobs_redo API
      freeze = false,
      -- State of execution
      action_state = npc.action_state.none,
      -- Action executed while on lock
      interrupted_action = {}
    }
  }

  -- This flag is checked on every step. If it is true, the rest of 
  -- Mobs Redo API is not executed
  ent.freeze = nil

  -- This map will hold all the places for the NPC
  -- Map entries should be like: "bed" = {x=1, y=1, z=1}
  ent.places_map = {}

  -- Temporary initialization of actions for testing
  local nodes = npc.places.find_node_nearby(ent.object:getpos(), {"default:furnace"}, 20)
  minetest.log("Found nodes: "..dump(nodes))

  --local path = pathfinder.find_path(ent.object:getpos(), nodes[1], 20)
  --minetest.log("Path to node: "..dump(path))
  --npc.add_action(ent, npc.actions.use_door, {self = ent, pos = nodes[1], action = npc.actions.door_action.OPEN})
  --npc.add_action(ent, npc.actions.stand, {self = ent})
  --npc.add_action(ent, npc.actions.stand, {self = ent})
  if nodes[1] ~= nil then
    npc.add_task(ent, npc.actions.walk_to_pos, {end_pos=nodes[1], walkable={}})
    npc.actions.use_furnace(ent, nodes[1], "default:cobble 5", false)
    --npc.add_action(ent, npc.actions.sit, {self = ent})
    -- npc.add_action(ent, npc.actions.lay, {self = ent})
    -- npc.add_action(ent, npc.actions.lay, {self = ent})
    -- npc.add_action(ent, npc.actions.lay, {self = ent})
    --npc.actions.use_sittable(ent, nodes[1], npc.actions.const.sittable.GET_UP)
    --npc.add_action(ent, npc.actions.set_interval, {self=ent, interval=10, freeze=true})
    npc.add_action(ent, npc.actions.freeze, {freeze = false})
  end

  -- Dedicated trade test
  ent.trader_data.trade_list.both = {
    ["default:tree"] = {},
    ["default:cobble"] = {},
    ["default:wood"] = {},
    ["default:diamond"] = {},
    ["default:mese_crystal"] = {},
    ["flowers:rose"] = {},
    ["advanced_npc:marriage_ring"] = {},
    ["flowers:geranium"] = {},
    ["mobs:meat"] = {},
    ["mobs:leather"] = {},
    ["default:sword_stone"] = {},
    ["default:shovel_stone"] = {},
    ["default:axe_stone"] = {}
  }

  npc.trade.generate_trade_offers_by_status(ent)

  -- Add a custom trade offer
  local offer1 = npc.trade.create_custom_sell_trade_offer("Do you want me to fix your steel sword?", "Fix steel sword", "Fix steel sword", "default:sword_steel", {"default:sword_steel", "default:iron_lump 5"})
  table.insert(ent.trader_data.custom_trades, offer1)
  local offer2 = npc.trade.create_custom_sell_trade_offer("Do you want me to fix your mese sword?", "Fix mese sword", "Fix mese sword", "default:sword_mese", {"default:sword_mese", "default:copper_lump 10"})
  table.insert(ent.trader_data.custom_trades, offer2)

  -- npc.add_action(ent, npc.action.stand, {self = ent})
  -- npc.add_action(ent, npc.action.stand, {self = ent})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.walk_step, {self = ent, dir = npc.direction.east})
  -- npc.add_action(ent, npc.action.sit, {self = ent})
  -- npc.add_action(ent, npc.action.rotate, {self = ent, dir = npc.direction.south})
  -- npc.add_action(ent, npc.action.lay, {self = ent})

  -- Temporary initialization of places
  -- local bed_nodes = npc.places.find_new_nearby(ent, npc.places.nodes.BEDS, 8)
  -- minetest.log("Number of bed nodes: "..dump(#bed_nodes))
  -- if #bed_nodes > 0 then
  --   npc.places.add_owned(ent, "bed1", npc.places.PLACE_TYPE.OWN_BED, bed_nodes[1])
  -- end

  minetest.log(dump(ent))
  
  -- Refreshes entity
  ent.object:set_properties(ent)
end


---------------------------------------------------------------------------------------
-- NPC Definition
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
  collisionbox = {-0.20,-1.0,-0.20, 0.20,0.8,0.20},
  --collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
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
	stepheight = 0.,
	walk_velocity = 1,
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

    -- Rotate NPC toward its clicker
    npc.dialogue.rotate_npc_to_player(self)

    -- Get information from clicker
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
        self,
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

    -- Timer function for casual traders to reset their trade offers  
    self.trader_data.change_offers_timer = self.trader_data.change_offers_timer + dtime
    -- Check if time has come to change offers
    if self.trader_data.trader_status == npc.trade.CASUAL and 
      self.trader_data.change_offers_timer >= self.trader_data.change_offers_timer_interval then
      -- Reset timer
      self.trader_data.change_offers_timer = 0
      -- Re-select casual trade offers
      npc.trade.generate_trade_offers_by_status(self)
    end
  
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
          --minetest.log(dump(self))
        end
      end
    end

    -- Action queue timer
    -- Check if actions and timers aren't locked
    if self.actions.action_timer_lock == false then
      -- Increment action timer
      self.actions.action_timer = self.actions.action_timer + dtime
      if self.actions.action_timer >= self.actions.action_interval then
        -- Reset action timer
        self.actions.action_timer = 0
        -- Execute action
        self.freeze = npc.execute_action(self)
        -- Check if there are still remaining actions in the queue
        if self.freeze == nil and table.getn(self.actions.queue) > 0 then
          self.freeze = false
        end
      end
    end
    
    return self.freeze
	end
})

-- Spawn
mobs:spawn({
	name = "advanced_npc:npc",
	nodes = {"mg_villages:plotmarker", "default:stone"},
	min_light = 3,
	active_object_count = 1,
  interval = 5,
  chance = 1,
	--max_height = 0,
	on_spawn = npc_spawn,
})

-------------------------------------------------------------------------
-- Item definitions
-------------------------------------------------------------------------

mobs:register_egg("advanced_npc:npc", S("NPC"), "default_brick.png", 1)

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
