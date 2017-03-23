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
-- Schedule functionality
---------------------------------------------------------------------------------------
-- Schedules allow the NPC to do different things depending on the time of the day.
-- The time of the day is in 24 hours and is consistent with the Minetest Game 
-- /time command. Hours will be written as numbers: 1 for 1:00, 13 for 13:00 or 1:00 PM
-- The API is as following: a schedule can be created for a specific date or for a
-- day of the week. A date is a string in the format MM:DD
npc.schedule_types = {
  ["generic"] = "generic",
  ["date_based"] = "date_based"
}

local function get_time_in_hours() 
  return minetest.get_timeofday() * 24
end

-- Create a schedule on a NPC.
-- Schedule types:
--  - Generic: Returns nil if there are already
--    seven schedules, one for each day of the
--    week or if the schedule attempting to add
--    already exists. The date parameter is the 
--    day of the week it represents as follows:
--      - 1: Monday
--      - 2: Tuesday
--      - 3: Wednesday
--      - 4: Thursday
--      - 5: Friday
--      - 6: Saturday
--      - 7: Sunday
--  - Date-based: The date parameter should be a
--    string of the format "MM:DD". If it already
--    exists, function retuns nil
function npc.create_schedule(self, schedule_type, date)
  if schedule_type == npc.schedule_types.generic then
    -- Check that there are no more than 7 schedules
    if #self.schedules.generic == 7 then
      -- Unable to add schedule
      return nil
    elseif #self.schedules.generic < 7 then
      -- Check schedule doesn't exists already
      if self.schedules.generic[date] == nil then
        -- Add schedule
        self.schedules.generic[date] = {}
      else
        -- Schedule already present
        return nil
      end
    end
  elseif schedule_type == npc.schedule_types.date then
    -- Check schedule doesn't exists already
    if self.schedules.date_based[date] == nil then
      -- Add schedule 
      self.schedules.date_based[date] = {}
    else
      -- Schedule already present
      return nil
    end
  end
end

function npc.delete_schedule(self, schedule_type, date)
  -- Delete schedule by setting entry to nil
  self.schedules[schedule_type][date] = nil
end

-- Schedule entries API
-- Allows to add, get, update and delete entries from each
-- schedule. Attempts to be as safe-fail as possible to avoid crashes. 

-- Actions is an array of actions and tasks that the NPC
-- will perform at the scheduled time on the scheduled date
function npc.add_schedule_entry(self, schedule_type, date, time, check, actions)
  -- Check that schedule for date exists
  if self.schedules[schedule_type][date] ~= nil then
    -- Add schedule entry
    if check == nil then
      self.schedules[schedule_type][date][time] = actions
    else
      self.schedules[schedule_type][date][time].check = check
    end
  else
    -- No schedule found, need to be created for date
    return nil
  end
end

function npc.get_schedule_entry(self, schedule_type, date, time)
  -- Check if schedule for date exists
  if self.schedules[schedule_type][date] ~= nil then
    -- Return schedule
    return self.schedules[schedule_type][date][time]
  else
    -- Schedule for date not found
    return nil
  end
end

function npc.update_schedule_entry(self, schedule_type, date, time, check, actions)
  -- Check schedule for date exists
  if self.schedules[schedule_type][date] ~= nil then
    -- Check that a schedule entry for that time exists
    if self.schedules[schedule_type][date][time] ~= nil then
      -- Set the new actions
      if check == nil then
        self.schedules[schedule_type][date][time] = actions
      else
        self.schedules[schedule_type][date][time].check = check
      end
    else
      -- Schedule not found for specified time
      return nil
    end
  else
    -- Schedule not found for date
    return nil
  end
end

function npc.delete_schedule_entry(self, schedule_type, date, time)
  -- Check schedule for date exists
  if self.schedules[schedule_type][date] ~= nil then
    -- Remove schedule entry by setting to nil
    self.schedules[schedule_type][date][time] = nil
  else
    -- Schedule not found for date
    return nil
  end
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

    if self.trader_data ~= nil then
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
    end
  
    if self.relationships ~= nil then
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
    end

    -- Action queue timer
    -- Check if actions and timers aren't locked
    if self.actions ~= nil then
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
    end

    -- Schedule timer
    -- Check if schedules are enabled
    if self.schedules ~= nil then
      if self.schedules.enabled == true then
        -- Get time of day
        local time = get_time_in_hours()
        -- Check if time is an hour
        if time % 1 < 0.1 and self.schedules.lock == false then
          -- Activate lock to avoid more than one entry to this code
          self.schedules.lock = true
          -- Get integer part of time
          time = (time) - (time % 1)
          -- Check if there is a schedule entry for this time
          -- Note: Currently only one schedule is supported, for day 0
          minetest.log("Time: "..dump(time))
          local schedule = self.schedules.generic[0]
          if schedule ~= nil then
            -- Check if schedule for this time exists
            minetest.log("Found default schedule")
            if schedule[time] ~= nil then
              -- Check if schedule has a check function
              if schedule[time].check ~= nil then
                -- Execute check function and then add corresponding action
                -- to action queue. This is for jobs.
                -- TODO: Need to implement
              else
                minetest.log("Adding actions to action queue")
                -- Add to action queue all actions on schedule
                for i = 1, #schedule[time] do
                  if schedule[time][i].action == nil then
                    -- Add task
                    npc.add_task(self, schedule[time][i].task, schedule[time][i].args)
                  else
                    -- Add action
                    npc.add_action(self, schedule[time][i].action, schedule[time][i].args)
                  end
                end
                minetest.log("New action queue: "..dump(self.actions))
              end
            end
          end
        else
          -- Check if lock can be released
          if time % 1 > 0.1 then
            -- Release lock
            self.schedules.lock = false
          end
        end
      end
    end

    return self.freeze
	end
})

-- Spawn
-- mobs:spawn({
-- 	name = "advanced_npc:npc",
-- 	nodes = {"mg_villages:plotmarker"},
-- 	min_light = 3,
-- 	active_object_count = 1,
--   interval = 5,
--   chance = 1,
-- 	--max_height = 0,
-- 	on_spawn = npc_spawn,
-- })

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
