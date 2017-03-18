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
-- npc.spawner.max_replace_count = 1
-- spawner.replace_count = 0

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



-- This function takes care of calculating how many NPCs will be spawn
function spawner.calculate_npc_spawning(pos)

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
      meta:set_string("nodedata", minetest.serialize(nodedata))
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
    run_at_every_load = true,
    action = function(pos, node)
      -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
      end
    end
  })

  -- ABM Registration... for when LBM fails.
  minetest.register_abm({
    label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    nodenames = {"mg_villages:plotmarker"},
    interval = 1.0,
    chance = 1,
    catch_up = true,
    action = function(pos, node, active_object_count, active_object_count_wider)
       -- Check if replacement is activated
      if npc.spawner.replace_activated then
        -- Replace mg_villages:plotmarker
        spawner.replace_mg_villages_plotmarker(pos)
      end
    end
  })

end