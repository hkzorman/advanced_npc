-- Advanced NPC spawner by Zorman2000
-- The advanced spawner will contain functionality to spawn NPC correctly on
-- mg_villages building. The spawn node will be the mg_villages:plotmarker.
-- This node will be replaced with one that will perform the following functions:
-- 
--  - Scan the current building, check if it is of type:
--    - House
--    - Farm
--    - Hut
--    - NOTE: All other types are unsupported as-of now
--  - If it's from any of the above types, the spawner will proceed to scan the
--    the building and find out: 
--    - Number and positions of beds
--    - Number and positions of benches
--    - Number and positions of chests
--    - Position of furnaces
--    - Position of doors
--    - NOTE: Scanning will be implemented for first floors only in the first
--            version. It's expected to also include upper floors later.
--  - After that, it will store these information in the node's metadata.
--  - The spawner will analyze the information and will spawn (# of beds/2) or 1
--    NPC in that house. The NPCs will be spawned in intervals, for which the node
--    will create node timers for each NPC.
--  - When a NPC is spawned:
--    - The NPC will be given a schedule
--      - If in a farm, the NPC will have a "farmer schedule" with a 40% chance
--      - If in a house or hut, the NPC will have either a miner, woodcutter, cooker
--        or simple schedule with an equal chance each
--    - The NPC will be assigned a unique bed
--    - The NPC will know the location of one chest, one bench and one furnace
--    - A life timer for the NPC will be created (albeit a long one). Once the NPC's
--      timer is invoked, the NPC will be de-spawned (dies). The spawner should keep
--      track of these.
--  - If a NPC has died, the spawner will choose with 50% chance to spawn a new NPC.
--
-- This is the basic functionality expected for the spawner in version 1. Other things
-- such as scanning upper floors, spawning families of NPCs and creating relationships
-- among them, etc. will be for other versions.

-- Public API
npc.spawner = {}
-- Private API
local spawner = {}

-- This is the official list of support building types
-- from the mg_villages mod
npc.spawner.mg_villages_supported_building_types = {
    "house",
    "farm_full",
    "farm_tiny",
    "hut",
    "lumberjack"
}

npc.spawner.replace_activated = true
npc.spawn_delay = 5
-- npc.spawner.max_replace_count = 1
-- spawner.replace_count = 0

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------
-- These functions are used at spawn time to determine several
-- random attributes for the NPC in case they are not already
-- defined. On a later phase, pre-defining many of the NPC values
-- will be allowed.

local function initialize_inventory()
  return {
    [1] = "",  [2] = "",  [3] = "",  [4] = "",
    [5] = "",  [6] = "",  [7] = "",  [8] = "",
    [9] = "",  [10] = "", [11] = "", [12] = "",
    [13] = "", [14] = "", [15] = "", [16] = "",
  }
end

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

-- Spawn function. Initializes all variables that the
-- NPC will have and choose random, starting values
local function spawn(entity, pos)
  minetest.log("Spawning new NPC: "..dump(entity))

  -- Get Lua Entity
  local ent = entity:get_luaentity()

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

  -- Schedule data
  ent.schedules = {
    -- Flag to enable or disable the schedules functionality
    enabled = true, 
    -- Lock for when executing a schedule
    lock = false,
    -- An array of schedules, meant to be one per day at some point
    -- when calendars are implemented. Allows for only 7 schedules,
    -- one for each day of the week
    generic = {},
    -- An array of schedules, meant to be for specific dates in the 
    -- year. Can contain as many as possible. The keys will be strings
    -- in the format MM:DD
    date_based = {}
  }

  -- Temporary initialization of actions for testing
  local nodes = npc.places.find_node_nearby(ent.object:getpos(), {"cottages:bench"}, 20)
  minetest.log("Found nodes: "..dump(nodes))

  --local path = pathfinder.find_path(ent.object:getpos(), nodes[1], 20)
  --minetest.log("Path to node: "..dump(path))
  --npc.add_action(ent, npc.actions.use_door, {self = ent, pos = nodes[1], action = npc.actions.door_action.OPEN})
  --npc.add_action(ent, npc.actions.stand, {self = ent})
  --npc.add_action(ent, npc.actions.stand, {self = ent})
  -- if nodes[1] ~= nil then
  --   npc.add_task(ent, npc.actions.walk_to_pos, {end_pos=nodes[1], walkable={}})
  --   npc.actions.use_furnace(ent, nodes[1], "default:cobble 5", false)
  --   --npc.add_action(ent, npc.actions.sit, {self = ent})
  --   -- npc.add_action(ent, npc.actions.lay, {self = ent})
  --   -- npc.add_action(ent, npc.actions.lay, {self = ent})
  --   -- npc.add_action(ent, npc.actions.lay, {self = ent})
  --   --npc.actions.use_sittable(ent, nodes[1], npc.actions.const.sittable.GET_UP)
  --   --npc.add_action(ent, npc.actions.set_interval, {self=ent, interval=10, freeze=true})
  --   npc.add_action(ent, npc.actions.freeze, {freeze = false})
  -- end

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

  -- Add a simple schedule for testing
  npc.create_schedule(ent, npc.schedule_types.generic, 0)
  -- Add schedule entries
  local morning_actions = { 
    [1] = {task = npc.actions.walk_to_pos, args = {end_pos=nodes[1], walkable={}} } ,
    [2] = {task = npc.actions.use_sittable, args = {pos=nodes[1], action=npc.actions.const.sittable.SIT} }, 
    [3] = {action = npc.actions.freeze, args = {freeze = true}}
  }
  npc.add_schedule_entry(ent, npc.schedule_types.generic, 0, 7, nil, morning_actions)
  local afternoon_actions = { [1] = {action = npc.actions.stand, args = {}} }
  npc.add_schedule_entry(ent, npc.schedule_types.generic, 0, 9, nil, afternoon_actions)
  -- local night_actions = {action: npc.action, args: {}}
  -- npc.add_schedule_entry(self, npc.schedule_type.generic, 0, 19, check, actions)

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
-- Scanning functions
---------------------------------------------------------------------------------------

-- Scans an area for the supported nodes: beds, benches,
-- furnaces, storage (e.g. chests) and openable (e.g. doors).
-- Returns a table with these classifications
function spawner.scan_area(start_pos, end_pos)
  minetest.log("Scanning area for nodes...")
  minetest.log("Start pos: "..dump(start_pos))
  minetest.log("End pos: "..dump(end_pos))
  local result = {
    bed_type = {},
    sittable_type = {},
    furnace_type = {},
    storage_type = {},
    openable_type = {}
  }

  result.bed_type = npc.places.find_node_in_area(start_pos, end_pos, npc.places.nodes.BED_TYPE)
  result.sittable_type = npc.places.find_node_in_area(start_pos, end_pos, npc.places.nodes.SITTABLE_TYPE)
  result.furnace_type = npc.places.find_node_in_area(start_pos, end_pos, npc.places.nodes.FURNACE_TYPE)
  result.storage_type = npc.places.find_node_in_area(start_pos, end_pos, npc.places.nodes.STORAGE_TYPE)
  result.openable_type = npc.places.find_node_in_area(start_pos, end_pos, npc.places.nodes.OPENABLE_TYPE)

  minetest.log("Found nodes inside area: "..dump(result))
  return result
end

-- This function is called when the node timer for spawning NPC
-- is expired 
function npc.spawner.spawn_npc(pos)
  -- Get timer
  local timer = minetest.get_node_timer(pos)
  -- Get metadata
  local meta = minetest.get_meta(pos)
  -- Check amount of NPCs that should be spawned
  local npc_count = meta:get_int("npc_count")
  local spawned_npc_count = meta:get_int("spawned_npc_count")
  minetest.log("Currently spawned "..dump(spawned_npc_count).." of "..dump(npc_count).." NPCs")
  if spawned_npc_count < npc_count then
    -- Spawn a NPC
    local npc = minetest.add_entity(pos, "advanced_npc:npc")
    if npc and npc:get_luaentity() then
      spawn(npc, pos)
      -- Increase NPC spawned count
      spawned_npc_count = spawned_npc_count + 1
      -- Store count into node
      meta:set_int("spawned_npc_count", spawned_npc_count)
      -- Check if there are more NPCs to spawn
      if spawned_npc_count >= npc_count then
        -- Stop timer
        timer:stop()
      end
      return true
    else
        npc:remove()
      return false
    end
  end
  
end

-- This function takes care of calculating how many NPCs will be spawn
function spawner.calculate_npc_spawning(pos)
  local meta = minetest.get_meta(pos)
  -- Get nodes for this building
  local node_data = minetest.deserialize(meta:get_string("node_data"))
  if node_data == nil then
    minetest.log("ERROR: Mis-configured advanced_npc:plotmarker_auto_spawner at position: "..dump(pos))
    return
  end
  -- Check number of beds
  local beds_count = #node_data.bed_type
  minetest.log("Number of beds: "..dump(beds_count))
  local npc_count = 0
  -- If number of beds is zero or beds/2 is less than one, spawn
  -- a single NPC.
  if beds_count == 0 or (beds_count > 0 and beds_count / 2 < 1) then
    -- Spawn a single NPC
    npc_count = 1
  else
    -- Spawn beds_count/2 NPCs
    npc_count = ((beds_count / 2) - ((beds_count / 2) % 1))
  end
  minetest.log("Will spawn "..dump(npc_count).." NPCs at "..dump(pos))
  -- Store amount of NPCs to spawn
  meta:set_int("npc_count", npc_count)
  -- Store amount of NPCs spawned
  meta:set_int("spawned_npc_count", 0)
  -- Start timer
  local timer = minetest.get_node_timer(pos)
  timer:start(npc.spawn_delay)
end

---------------------------------------------------------------------------------------
-- Support code for mg_villages mods
---------------------------------------------------------------------------------------

-- This function creates a table of the scannable nodes inside
-- a mg_villages building. It needs the plotmarker position for a start
-- point and the building_data to get the x, y and z-coordinate size
-- of the building schematic
function spawner.scan_mg_villages_building(pos, building_data)
  -- Get area of the building
  local x_size = building_data.sizex
  local y_size = building_data.ysize
  local z_size = building_data.sizez
  local start_pos = {x=pos.x, y=pos.y, z=pos.z}
  local end_pos = {x=pos.x + x_size, y=pos.y + y_size, z=pos.z + z_size}

  return spawner.scan_area(start_pos, end_pos)
end

-- This function replaces an existent mg_villages:plotmarker with
-- and advanced_npc:auto_spawner. The existing metadata will be kept,
-- to allow compatibility. A new formspec will appear on right-click,
-- however it will as well allow to buy or manage the plot.
-- Also, the building is scanned for NPC-usable nodes and the amount
-- of NPCs to spawn and the interval is calculated.
function spawner.replace_mg_villages_plotmarker(pos)
  -- Get the meta at the current position
  local meta = minetest.get_meta(pos)
  local village_id = meta:get_string("village_id")
  local plot_nr = meta:get_int("plot_nr")
  local infotext = meta:get_string("infotext")
  -- Following line from mg_villages mod, protection.lua
  local btype = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr].btype
  local building_data = mg_villages.BUILDINGS[btype]
  local building_type = building_data.typ 
  -- Check if the building is of the support types
  for _,value in pairs(npc.spawner.mg_villages_supported_building_types) do

    if building_type == value then

      minetest.log("Replacing mg_villages:plotmarker at "..dump(pos))
      -- Replace the plotmarker for auto-spawner
      minetest.set_node(pos, {name="advanced_npc:plotmarker_auto_spawner"})
      -- Store old plotmarker metadata again
      meta:set_string("village_id", village_id)
      meta:set_int("plot_nr", plot_nr)
      meta:set_string("infotext", infotext)
      -- Store building type in metadata
      meta:set_string("building_type", building_type)
      -- Scan building for nodes
      local nodedata = spawner.scan_mg_villages_building(pos, building_data)
      -- Store nodedata into the spawner's metadata
      meta:set_string("node_data", minetest.serialize(nodedata))
      -- Stop searching for building type
      break

    end
  end
end

-- Only register the node, the ABM and the LBM if mg_villages mod
-- is present
if minetest.get_modpath("mg_villages") ~= nil then

  -- Node registration
  -- This node is currently a slightly modified mg_villages:plotmarker
  -- TODO: Change formspec to a more detailed one.
  minetest.register_node("advanced_npc:plotmarker_auto_spawner", {
    description = "Automatic NPC Spawner",
    drawtype = "nodebox",
    tiles = {"default_stone.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5+2/16, -0.5, -0.5+2/16,  0.5-2/16, -0.5+2/16, 0.5-2/16},
        }
    },
    groups = {cracky=3,stone=2},

    on_rightclick = function( pos, node, clicker, itemstack, pointed_thing)
      return mg_villages.plotmarker_formspec( pos, nil, {}, clicker )
    end,

    on_receive_fields = function(pos, formname, fields, sender)
      return mg_villages.plotmarker_formspec( pos, formname, fields, sender );
    end,

    on_timer = function(pos, elapsed)
      minetest.log("Calling spawning function...")
      npc.spawner.spawn_npc(pos)
    end,

    -- protect against digging
    can_dig = function(pos, player)
      local meta = minetest.get_meta(pos);
      if (meta and meta:get_string("village_id") ~= "" and meta:get_int("plot_nr") and meta:get_int("plot_nr") > 0 ) then
          return false;
      end
      return true;
    end
  })

  -- LBM Registration
  -- Used to modify plotmarkers and replace them with advanced_npc:plotmarker_auto_spawner
  minetest.register_lbm({
    label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    name = "advanced_npc:mg_villages_plotmarker_replacer",
    nodenames = {"mg_villages:plotmarker"},
    run_at_every_load = false,
    action = function(pos, node)
      -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
        -- Set NPCs to spawn
        spawner.calculate_npc_spawning(pos)
      end
    end
  })

  -- ABM Registration... for when LBM fails.
  minetest.register_abm({
    label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    nodenames = {"mg_villages:plotmarker"},
    interval = 60,
    chance = 1,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
       -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
        -- Set NPCs to spawn
        spawner.calculate_npc_spawning(pos)
      end
    end
  })

end

-- Chat commands to manage spawners

minetest.register_chatcommand("restore_plotmarkers", {
  description = "Replaces all advanced_npc:plotmarker_auto_spawner with mg_villages:plotmarker in the specified radius.",
  privs = {server=true},
  func = function(name, param)
    -- Check if radius is null
    if param == nil then
      minetest.chat_send_player(name, "Need to enter a radius as an integer number. Ex. /restore_plotmarkers 10 for a radius of 10")
    end
    -- Get player position
    local pos = {}
    for _,player in pairs(minetest.get_connected_players()) do
      if player:get_player_name() == name then
        pos = player:get_pos()
        break
      end
    end
    -- Search for nodes
    local radius = tonumber(param)
    local start_pos = {x=pos.x - radius, y=pos.y - radius, z=pos.z - radius}
    local end_pos = {x=pos.x + radius, y=pos.y + radius, z=pos.z + radius}
    local nodes = minetest.find_nodes_in_area_under_air(start_pos, end_pos, 
      {"advanced_npc:plotmarker_auto_spawner"})
    -- Check if we have nodes to replace
    minetest.chat_send_player(name, "Found "..dump(#nodes).." nodes to replace...")
    if #nodes == 0 then
      return
    end
    -- Replace all nodes
    for i = 1, #nodes do
      minetest.log(dump(nodes[i]))
      local meta = minetest.get_meta(nodes[i])
      local village_id = meta:get_string("village_id")
      local plot_nr = meta:get_int("plot_nr")
      local infotext = meta:get_string("infotext")
      -- Replace node
      minetest.set_node(nodes[i], {name="mg_villages:plotmarker"})
      -- Set metadata
      meta = minetest.get_meta(nodes[i])
      meta:set_string("village_id", village_id)
      meta:set_int("plot_nr", plot_nr)
      meta:set_string("infotext", infotext)
    end
    minetest.chat_send_player(name, "Finished "..dump(#nodes).." replacement successfully")
  end
})