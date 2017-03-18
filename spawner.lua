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

-- This is the official list of support building types
-- from the mg_villages mod
local mg_villages_supported_building_types = {
    "house",
    "farm_full",
    "farm_tiny",
    "hut",
    "lumberjack"
}

local replace_activated = true
local max_replace_count = 1
local replace_count = 0

-- Node registration
-- This node is currently a slightly modified mg_villages:plotmarker
minetest.register_node("advanced_npc:auto_spawner", {
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

-- Scans an area for the supported nodes: beds, benches,
-- furnaces, storage (e.g. chests) and openable (e.g. doors).
-- Returns a table with these classifications
local function scan_area(start_pos, end_pos)
  local result = {
    bed_type = {},
    sittable_type = {},
    furnace_type = {},
    storage_type = {},
    openable_type = {}
  }

  


end

-- This function creates a table of the scannable nodes inside
-- a mg_villages building. It needs the plotmarker position for a start
-- point and the building_data to get the x, y and z-coordinate size
-- of the building schematic
local function scan_mg_villages_building(pos, building_data)
  -- Get area of the building
  local x_size = building_data.sizex
  local y_size = building_data.ysize
  local z_size = building_data.sizez
  local start_pos = {x=pos.x, y=pos.y, z=pos.z}
  local end_pos = {x=pos.x + x_size, y=pos.y + y_size, z=pos.z + z_size}

  return scan_area(start_pos, end_pos)
end


if minetest.get_modpath("mg_villages") ~= nil then
    -- LBM Registration
    -- Used to modify plotmarkers and replace them with advanced_npc:auto_spawner
    minetest.register_lbm({
        label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
        name = "advanced_npc:mg_villages_plotmarker_replacer",
        nodenames = {"mg_villages:plotmarker"},
        run_at_every_load = true,
        action = function(pos, node)
            -- Check if replacement is activated
            if replace_activated then
                -- Check if limit has been reached
                if replace_count < max_replace_count then
                    -- Get the meta at the current position
                    local meta = minetest.get_meta(pos)
                    local village_id = meta:get_string("village_id")
                    local plot_nr = meta:get_int("plot_nr")
                    local infotext = meta:get_string("infotext")
                    -- Following line from mg_villages mod, protection.lua
                    local btype = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr].btype
                    minetest.log("All info: "..dump(mg_villages.BUILDINGS[btype]))
                    local building_data = mg_villages.BUILDINGS[btype]
                    local building_type = building_data.typ 
                    -- Check if the building is of the support types
                    for _,value in pairs(mg_villages_supported_building_types) do
                      minetest.log("Current value: "..dump(value))
                        if building_type == value then
                            -- Replace the plotmarker for auto-spawner
                            minetest.set_node(pos, {name="advanced_npc:auto_spawner"})
                            -- Set the old plotmarker meta again
                            meta:set_string("village_id", village_id)
                            meta:set_int("plot_nr", plot_nr)
                            meta:set_string("infotext", infotext)
                            

                            -- Increase count of modified nodes
                            replace_count = replace_count + 1
                        end
                    end
                end
            end
        end
    })
end