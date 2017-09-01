-- Advanced NPC spawner by Zorman2000
-- The advanced spawner will contain functionality to spawn NPC correctly on
-- custom places, as well as in mg_villages building.
-- This works by using a special node to spawn NPCs on either a custom building or
-- on mg_villages building.

-- mg_villages functionality:
-- The spawn node for mg_villages will be the mg_villages:plotmarker.
-- Based on this node, the following things will be performed
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
npc.spawner.replacement_interval = 60
npc.spawner.spawn_delay = 10

npc.spawner.spawn_data = {
    status = {
        dead = 0,
        alive = 1
    },
    age = {
        adult = "adult",
        child = "child"
    }
}

-- Array of nodes that serve as plotmarker of a plot, and therefore
-- as auto-spawners
spawner.plotmarker_nodes = {}
-- Array of items that are used to spawn NPCs
spawner.spawn_eggs = {}

---------------------------------------------------------------------------------------
-- Scanning functions
---------------------------------------------------------------------------------------

-- This function scans a 3D area that encloses a building and tries to identify:
--  - Entrance door
--  - Beds
--  - Storage nodes (chests, etc.)
--  - Furnace nodes
--  - Sittable nodes
-- It will return a table with all information gathered
-- Playername should be provided if manual spawning
function npc.spawner.scan_area_for_spawn(start_pos, end_pos, player_name)
    local result = {
        building_type = "",
        building_plot_info = {},
        building_entrance = {},
        building_usable_nodes = {},
        building_npcs = {},
        building_npc_stats = {}
    }

    -- Set building_type
    result.building_type = "custom"
    -- Get min pos and max pos
    local minp, maxp = vector.sort(start_pos, end_pos)
    -- Set plot info
    result.building_plot_info = {
        -- TODO: Check this and see if it is accurate!
        xsize = maxp.x - minp.x,
        ysize = maxp.y - minp.y,
        zsize = maxp.z - minp.z,
        start_pos = start_pos,
        end_pos = end_pos
    }

    -- Scan building nodes
    -- Scan building for nodes
    local usable_nodes = npc.places.scan_area_for_usable_nodes(start_pos, end_pos)
    -- Get all doors
    local doors = usable_nodes.openable_type

    -- Find entrance node - this is very tricky when no outside position
    -- is given. So to this end, three things will happen:
    --  - First, we will check for plotmarker nodes. A plotmarker node should
    --    be set at the left of the front door of the building. If this node is
    --    found, it will assume it is at that location and use it.
    --  - Second, we are going to search for an entrance marker. The entrance marker
    --    will be directly in the posiition of the entrance node, so no search
    --    is needed.
    --  - Third, will assume that the start_pos is always at the left side of
    --    the front of the building, where the entrance is
    local outside_pos = start_pos
    -- Check if there is a plotmarker or spawner node
    local candidate_nodes = minetest.find_nodes_in_area_under_air(start_pos, end_pos,
        {"mg_villages:plotmarker", "advanced_npc:auto_spawner"})
    if table.getn(candidate_nodes) > 0 then
        -- Found plotmarker, use it as outside_pos. Ideally should be only one
        outside_pos = candidate_nodes[1]
    elseif npc.spawner_marker and player_name then
        -- Get entrance from spawner marker1
        if npc.spawner_marker.entrance_markers[player_name] then
            outside_pos = npc.spawner_marker.entrance_markers[player_name]
        end
    end
    -- Try to find entrance
    local entrance = npc.places.find_entrance_from_openable_nodes(doors, outside_pos)
    if entrance then
        npc.log("INFO", "Found building entrance at: "..minetest.pos_to_string(entrance.node_pos))
        -- Set building entrance
        result.building_entrance = entrance
    else
        npc.log("ERROR", "Unable to find building entrance!")
    end

    -- Set node_data
    result.building_usable_nodes = usable_nodes

    -- Initialize NPC stats
    -- Initialize NPC stats
    local npc_stats = {
        male = {
            total = 0,
            adult = 0,
            child = 0
        },
        female = {
            total = 0,
            adult = 0,
            child = 0
        },
        adult_total = 0,
        child_total = 0
    }
    result.building_npc_stats = npc_stats

    return result
end

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------

function npc.spawner.determine_npc_occupation(building_type, workplace_nodes, npcs)
    local surrounding_buildings_map = {}
    local current_building_map = {}
    local current_building_npc_occupations = {}
    -- Get all occupation names in the current building
    for i = 1, #npcs do
        if not npc.utils.array_contains(current_building_npc_occupations, npcs[i].occupation) then
            table.insert(current_building_npc_occupations, npcs[i].occupations)
        end
    end
    minetest.log("Occupation names in current building: "..dump(current_building_npc_occupations))
    -- Classify workplaces
    for i = 1, #workplace_nodes do
        local workplace = workplace_nodes[i]
        if workplace.surrounding_workplace == true then
            surrounding_buildings_map[workplace.building_type] = workplace
        else
            current_building_map[workplace.building_type] = workplace
        end
    end

    minetest.log("Surrounding workplaces map: "..dump(surrounding_buildings_map))
    minetest.log("Current building type: "..dump(building_type))
    -- Get occupation names for the buildings
    local occupation_names = npc.occupations.get_for_building(
        building_type,
        npc.utils.get_map_keys(surrounding_buildings_map)
    )
    -----------------------
    -- Determine occupation
    -----------------------
    -- First of all, iterate through all names, discard the default basic occupation.
    -- Next, check if no-one in this builiding has this occupation name.
    -- Next, check if the workplace node has no data assigned to it.
    -- Finally, if not, return an table with the occupation name, and the selected
    -- workplace node.
    -- Note: Much more can be done here. This is a simplistic implementation,
    -- given this is already complicated enough. For example, existing NPCs' occupation
    -- can play a much more important role, not only taken in consideration for discarding.
    for i = 1, #occupation_names do
        -- Check if this occupation name is the default occupation, and if it is, continue
        if occupation_names[i] ~= npc.occupations.basic_name then
            -- Check if someone already works on this
            if not npc.utils.array_contains(current_building_npc_occupations, occupation_names[i]) then
                -- Check if someone else already has this occupation at the same workplace
                for j = 1, #workplace_nodes do
                    -- Get building types from occupation
                    local local_building_types =
                    npc.occupations.registered_occupations[occupation_names[i]].building_type or {}
                    local surrounding_building_types =
                    npc.occupations.registered_occupations[occupation_names[i]].surrounding_building_types or {}
                    minetest.log("Occupation btype: "..dump(local_building_types))
                    minetest.log("Surrounding btypes: "..dump(surrounding_building_types))
                    -- Check the workplace_node is of any of those building_types
                    if npc.utils.array_contains(local_building_types, workplace_nodes[j].building_type) or
                            npc.utils.array_contains(surrounding_building_types, workplace_nodes[j].building_type) then
                        minetest.log("Found corresponding node: "..dump(workplace_nodes[j]))
                        local meta = minetest.get_meta(workplace_nodes[j].node_pos)
                        local worker_data = minetest.deserialize(meta:get_string("work_data") or "")
                        -- If no worker data is found, then create it
                        if not worker_data then
                            return {name=occupation_names[i], node=workplace_nodes[j]}
                        end
                    end
                end

            end
        end
    end
    return {name=npc.occupations.basic_name, node={}}
end

-- This function is called when the node timer for spawning NPC
-- is expired. Can be called manually by supplying either:
--   - Position of mg_villages plotmarker, or,
--   - position of custom building spawner
-- Prerequisite for calling this function is:
--  - In case of mg_villages, spawner.adapt_mg_villages_plotmarker(), or,
--  - in case of custom buildings, npc.spawner.scan_area_for_spawn()
function npc.spawner.spawn_npc_on_plotmarker(pos)
    -- Get timer
    local timer = minetest.get_node_timer(pos)
    -- Get metadata
    local meta = minetest.get_meta(pos)
    -- Get current NPC info
    local area_info = {}
    area_info["npcs"] = minetest.deserialize(meta:get_string("npcs"))
    -- Get NPC stats
    area_info["npc_stats"] = minetest.deserialize(meta:get_string("npc_stats"))
    -- Get node data
    area_info["entrance"] = minetest.deserialize(meta:get_string("entrance"))
    area_info["node_data"] = minetest.deserialize(meta:get_string("node_data"))
    -- Check amount of NPCs that should be spawned
    area_info["npc_count"] = meta:get_int("npc_count")
    area_info["spawned_npc_count"] = meta:get_int("spawned_npc_count")

    -- Determine occupation
    area_info["building_type"] = meta:get_string("building_type")
    local nearby_plotmarkers = minetest.deserialize(meta:get_string("nearby_plotmarkers"))
    --minetest.log("BEFORE Workplace nodes: "..dump(area_info.node_data.workplace_type))
    local occupation_data = npc.spawner.determine_npc_occupation(
        area_info.building_type,
        area_info.node_data.workplace_type,
        area_info.npcs)

    --minetest.log("AFTER Workplace nodes: "..dump(area_info.node_data.workplace_type))
    -- Assign workplace node
    if occupation_data then
        for i = 1, #area_info.node_data.workplace_type do
            if area_info.node_data.workplace_type[i].node_pos == occupation_data.node.node_pos then
                -- Found node, mark it as being used by NPC
                area_info.node_data.workplace_type[i]["occupation"] = occupation_data.name
            end
        end
    end

    -- Spawn NPC
    local metadata = npc.spawner.spawn_npc(pos, area_info, occupation_data.name, occupation_data.node.node_pos)

    -- Set all metadata back into the node
    -- Increase NPC spawned count
    area_info.spawned_npc_count = metadata.spawned_npc_count + 1
    -- Store count into node
    meta:set_int("spawned_npc_count", area_info.spawned_npc_count)
    -- Store spawned NPC info
    meta:set_string("npcs", minetest.serialize(metadata.npcs))
    -- Store NPC stats
    meta:set_string("npc_stats", minetest.serialize(metadata.npc_stats))

    -- Check if there are more NPCs to spawn
    if area_info.spawned_npc_count >= area_info.npc_count then
        -- Stop timer
        npc.log("INFO", "No more NPCs to spawn at this location")
        timer:stop()
    else
        -- Start another timer to spawn more NPC
        local new_delay = math.random(npc.spawner.spawn_delay)
        npc.log("INFO", "Spawning one more NPC in "..dump(npc.spawner.spawn_delay).."s")
        timer:start(new_delay)
    end
end

-- This function spawns a NPC into the given pos.
-- If area_info is given, updated area_info is returned at end
function npc.spawner.spawn_npc(pos, area_info, occupation_name, occupation_workplace_pos)
    -- Get current NPC info
    local npc_table = area_info.npcs
    -- Get NPC stats
    local npc_stats = area_info.npc_stats
    -- Get building entrance
    local entrance = area_info.entrance
    -- Get node data
    local node_data = area_info.node_data
    -- Check amount of NPCs that should be spawned
    local npc_count = area_info.npc_count
    local spawned_npc_count = area_info.spawned_npc_count
    -- Check if we actually have these variables - if we don't, it is because
    -- this is a manually spawned NPC
    local can_spawn = false
    if npc_count and spawned_npc_count then
        npc.log("INFO", "Currently spawned "..dump(spawned_npc_count).." of "..dump(npc_count).." NPCs")
        if spawned_npc_count < npc_count then
            can_spawn = true
        end
    else
        -- Manually spawned
        can_spawn = true
    end

    if can_spawn then
        npc.log("INFO", "Spawning NPC at "..minetest.pos_to_string(pos))
        -- Spawn a NPC
        local ent = minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, "advanced_npc:npc")
        if ent and ent:get_luaentity() then
            ent:get_luaentity().initialized = false
            -- Determine NPC occupation - use given or default
            local occupation = occupation_name or "default_basic"
            -- Initialize NPC
            -- Call with stats if there are NPCs
            if npc_table and #npc_table > 0 then
                npc.initialize(ent, pos, false, npc_stats, occupation)
            else
                npc.initialize(ent, pos, nil, nil, occupation)
            end
            -- If entrance and node_data are present, assign nodes
            if entrance and node_data then
                npc.spawner.assign_places(ent:get_luaentity(), entrance, node_data, pos)
            end
            -- Store spawned NPC data and stats into node
            local age = npc.age.adult
            if ent:get_luaentity().child then
                age = npc.age.child
            end
            local entry = {
                status = npc.spawner.spawn_data.status.alive,
                name = ent:get_luaentity().name,
                id = ent:get_luaentity().npc_id,
                sex = ent:get_luaentity().sex,
                age = age,
                occupation = occupation,
                workplace = occupation_workplace_pos,
                born_day = minetest.get_day_count()
            }
            minetest.log("Area info: "..dump(area_info))
            table.insert(area_info.npcs, entry)
            -- Update and store stats
            -- Increase total of NPCs for specific sex
            npc_stats[ent:get_luaentity().sex].total =
            npc_stats[ent:get_luaentity().sex].total + 1
            -- Increase total number of NPCs by age
            npc_stats[age.."_total"] = npc_stats[age.."_total"] + 1
            -- Increase number of NPCs by age and sex
            npc_stats[ent:get_luaentity().sex][age] =
            npc_stats[ent:get_luaentity().sex][age] + 1
            area_info.npc_stats = npc_stats
            -- Return
            npc.log("INFO", "Spawning successful!")
            return area_info
        else
            npc.log("ERROR", "Spawning failed!")
            ent:remove()
            return false
        end
    end
end

-- This function will assign places to every NPC that belongs to a specific
-- house/building. It will use the resources of the building and give them
-- until there's no more. Call this function after NPCs are initialized
-- The basic assumption:
--   - Tell the NPC where the furnaces are
--   - Assign a unique bed to the NPC
--   - If there are as many chests as beds, assign one to a NPC
--     - Else, just let the NPC know one of the chests, but not to be owned
--   - If there are as many benches as beds, assign one to a NPC
--     - Else, just let the NPC know one of the benches, but not own them
--   - Let the NPC know all doors to the house. Identify the front one as the entrance
-- Self is the NPC lua entity object, pos is the position of the NPC spawner.
-- Prerequisite for using this function is to have called either
--  - In case of mg_villages, spawner.adapt_mg_villages_plotmarker(), or,
--  - in case of custom buildings, npc.spawner.scan_area_for_spawn()
-- Both function set the required metadata for this function
-- For mg_villages, this will be the position of the plotmarker node.
function npc.spawner.assign_places(self, entrance, node_data, pos)
    -- Assign plotmarker if position given
    if pos then
        npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_PLOTMARKER,
            npc.places.PLACE_TYPE.OTHER.HOME_PLOTMARKER, pos)
    end

    -- Assign entrance door and related locations
    if entrance ~= nil and entrance.node_pos ~= nil then
        npc.places.add_shared(self, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, npc.places.PLACE_TYPE.OPENABLE.HOME_ENTRANCE_DOOR, entrance.node_pos)
        -- Find the position inside and outside the door
        local entrance_inside = npc.places.find_node_behind_door(entrance.node_pos)
        local entrance_outside = npc.places.find_node_in_front_of_door(entrance.node_pos)
        -- Assign these places to NPC
        npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, npc.places.PLACE_TYPE.OTHER.HOME_INSIDE, entrance_inside)
        npc.places.add_shared(self, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE, entrance_outside)
    end

    -- Assign beds
    if #node_data.bed_type > 0 then
        -- Assign a specific sittable node to a NPC.
        npc.places.add_owned_accessible_place(self, node_data.bed_type,
            npc.places.PLACE_TYPE.BED.PRIMARY)
        -- Store changes to node_data
        --meta:set_string("node_data", minetest.serialize(node_data))
    end

    -- Assign sits
    if #node_data.sittable_type > 0 then
        -- Check if there are same or more amount of sits as beds
        if #node_data.sittable_type >= #node_data.bed_type then
            -- Assign a specific sittable node to a NPC.
            npc.places.add_owned_accessible_place(self, node_data.sittable_type,
                npc.places.PLACE_TYPE.SITTABLE.PRIMARY)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all sits to places as shared since NPC should be able to sit
        -- at any accessible sit
        npc.places.add_shared_accessible_place(self, node_data.sittable_type,
            npc.places.PLACE_TYPE.SITTABLE.SHARED)
    end

    -- Assign furnaces
    if #node_data.furnace_type > 0 then
        -- Check if there are same or more amount of furnace as beds
        if #node_data.furnace_type >= #node_data.bed_type then
            -- Assign a specific furnace node to a NPC.
            npc.places.add_owned_accessible_place(self, node_data.furnace_type,
                npc.places.PLACE_TYPE.FURNACE.PRIMARY)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all furnaces to places as shared since NPC should be able to use
        -- any accessible furnace
        npc.places.add_shared_accessible_place(self, node_data.furnace_type,
            npc.places.PLACE_TYPE.FURNACE.SHARED)
    end

    -- Assign storage nodes
    if #node_data.storage_type > 0 then
        -- Check if there are same or more amount of storage as beds
        if #node_data.storage_type >= #node_data.bed_type then
            -- Assign a specific storage node to a NPC.
            npc.places.add_owned_accessible_place(self, node_data.storage_type,
                npc.places.PLACE_TYPE.STORAGE.PRIMARY)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all storage-types to places as shared since NPC should be able
        -- to use other storaage nodes as well.
        npc.places.add_shared_accessible_place(self, node_data.storage_type,
            npc.places.PLACE_TYPE.STORAGE.SHARED)
    end

    -- Assign workplace nodes
    if #node_data.workplace_type > 0 then
        -- First, find the workplace_node that was marked
        for i = 1, #node_data.workplace_type do
            minetest.log("In assign places: workplace nodes: "..dump(node_data.workplace_type))
            if node_data.workplace_type[i].occupation
                    and node_data.workplace_type[i].occupation == self.occupation_name then
                -- Found the node. Assign only this node to the NPC.
                npc.places.add_shared_accessible_place(self, {node_data.workplace_type[i]},
                    npc.places.PLACE_TYPE.WORKPLACE.PRIMARY)
                -- Edit metadata of this workplace node to not allow it for other NPCs
                local meta = minetest.get_meta(node_data.workplace_type[i].node_pos)
                local work_data = {
                    npc_name = self.npc_name,
                    occupation = self.occupation_name,
                    multiple_npcs =
                    npc.occupations.registered_occupations[self.occupation_name].allow_multiple_npcs_at_workplace
                }
                meta:set_string("work_data", minetest.serialize(work_data))
                --
                --                meta = minetest.get_meta(node_data.workplace_type[i].node_pos)
                --                minetest.log("Work data: "..dump(minetest.deserialize(meta:get_string("work_data"))))
            end
        end
    end

    npc.log("DEBUG", "Places for NPC "..self.npc_name..": "..dump(self.places_map))

    -- Make NPC go into their house
    -- If entrance is available let NPC
    if entrance then
        npc.add_task(self,
            npc.actions.cmd.WALK_TO_POS,
            {end_pos=npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
                walkable={}})
        npc.add_action(self, npc.actions.cmd.FREEZE, {freeze = false})
    end

    return node_data
end

-- This function takes care of calculating how many NPCs will be spawn
-- Prerequisite for calling this function is:
--  - In case of mg_villages, spawner.adapt_mg_villages_plotmarker(), or,
--  - in case of custom buildings, npc.spawner.scan_area_for_spawn()
function npc.spawner.calculate_npc_spawning_on_plotmarker(pos)
    -- Check node metadata
    local meta = minetest.get_meta(pos)
    if meta:get_string("replaced") ~= "true" then
        return
    end
    -- Get nodes for this building
    local node_data = minetest.deserialize(meta:get_string("node_data"))
    if node_data == nil then
        npc.log("ERROR", "Mis-configured spawner at position: "..minetest.pos_to_string(pos))
        return
    end
    -- Check number of beds
    local beds_count = #node_data.bed_type--#spawner.filter_first_floor_nodes(node_data.bed_type, pos)

    npc.log("DEBUG", "Found "..dump(beds_count).." beds in the building at "..minetest.pos_to_string(pos))
    local npc_count = 0
    -- If number of beds is zero or beds/2 is less than one, spawn
    -- a single NPC.
    if beds_count == 0 or (beds_count > 0 and beds_count / 2 < 1) then
        -- Spawn a single NPC
        npc_count = 1
    else
        -- Spawn (beds_count/2) NPCs
        npc_count = ((beds_count / 2) - ((beds_count / 2) % 1))
    end
    npc.log("INFO", "Will spawn "..dump(npc_count).." NPCs at "..minetest.pos_to_string(pos))
    -- Store amount of NPCs to spawn
    meta:set_int("npc_count", npc_count)
    -- Store amount of NPCs spawned
    meta:set_int("spawned_npc_count", 0)
    -- Start timer
    local timer = minetest.get_node_timer(pos)
    local delay = math.random(npc.spawner.spawn_delay)
    timer:start(delay)
end

---------------------------------------------------------------------------------------
-- Spawner nodes and items
---------------------------------------------------------------------------------------
-- The following are included:
--  - Auto-spawner: Basically a custom mg_villages:plotmarker that can be used
--    for custom buildings
--  - Manual spawner: This custom spawn item (egg) will show a formspec when used.
--    The formspec will allow the player to set the name of the NPC, the occupation
--    and the plot, entrance and workplace of the NPC. All of these are optional
--    and default values will be chosen whenever no input is provided.


---------------------------------------------------------------------------------------
-- Support code for mg_villages mods
---------------------------------------------------------------------------------------
if minetest.get_modpath("mg_villages") ~= nil then

    -- This function creates a table of the scannable nodes inside
    -- a mg_villages building. It needs the plotmarker position for a start
    -- point and the building_data to get the x, y and z-coordinate size
    -- of the building schematic
    function spawner.scan_mg_villages_building(pos, building_data)
        --minetest.log("--------------------------------------------")
        --minetest.log("Building data: "..dump(building_data))
        --minetest.log("--------------------------------------------")
        -- Get area of the building
        local x_size = building_data.bsizex
        local y_size = building_data.ysize
        local z_size = building_data.bsizez
        local brotate = building_data.brotate
        local start_pos = {x=pos.x, y=pos.y, z=pos.z}
        local x_sign, z_sign = 1, 1

        -- Check plot direction
        -- NOTE: Below values may be wrong, very wrong!
        -- 0 - facing West, -X
        -- 1 - facing North, +Z
        -- 2 - facing East, +X
        -- 3 - facing South -Z
        if brotate == 0 then
            x_sign, z_sign = 1, -1
        elseif brotate == 1 then
            x_sign, z_sign =  -1, -1
            local temp = z_size
            z_size = x_size
            x_size = temp
        elseif brotate == 2 then
            x_sign, z_sign = -1, 1
        elseif brotate == 3 then
            x_sign, z_sign = 1, 1
        end

        ------------------------
        -- For debug:
        ------------------------
        -- Red is x marker
        --minetest.set_node({x=pos.x + (x_sign * x_size),y=pos.y,z=pos.z}, {name = "wool:red"})
        --minetest.get_meta({x=pos.x + (x_sign * x_size),y=pos.y,z=pos.z}):set_string("infotext", minetest.get_meta(pos):get_string("infotext")..", Axis: x, Sign: "..dump(x_sign))
        -- Blue is z marker
        --minetest.set_node({x=pos.x,y=pos.y,z=pos.z + (z_sign * z_size)}, {name = "wool:blue"})
        --minetest.get_meta({x=pos.x,y=pos.y,z=pos.z + (z_sign * z_size)}):set_string("infotext", minetest.get_meta(pos):get_string("infotext")..", Axis: z, Sign: "..dump(z_sign))

        npc.log("DEBUG", "Start pos: "..minetest.pos_to_string(start_pos))
        npc.log("DEBUG", "Plot: "..dump(minetest.get_meta(start_pos):get_string("infotext")))

        npc.log("DEBUG", "Brotate: "..dump(brotate))
        npc.log("DEBUG", "X_sign: "..dump(x_sign))
        npc.log("DEBUG", "X_adj: "..dump(x_sign*x_size))
        npc.log("DEBUG", "Z_sign: "..dump(z_sign))
        npc.log("DEBUG", "Z_adj: "..dump(z_sign*z_size))

        local end_pos = {x=pos.x + (x_sign * x_size), y=pos.y + y_size, z=pos.z + (z_sign * z_size)}

        -- For debug:
        --minetest.set_node(start_pos, {name="default:mese_block"})
        --minetest.set_node(end_pos, {name="default:mese_block"})
        --minetest.get_meta(end_pos):set_string("infotext", minetest.get_meta(start_pos):get_string("infotext"))

        npc.log("DEBUG", "Calculated end pos: "..minetest.pos_to_string(end_pos))

        return npc.places.scan_area_for_usable_nodes(start_pos, end_pos)
    end

    -- This function "adapts" an existent mg_villages:plotmarker for NPC spawning.
    -- The existing metadata will be kept, to allow compatibility. A new formspec
    -- will appear on right-click, however it will as well allow to buy or manage
    -- the plot. Also, the building is scanned for NPC-usable nodes and the amount
    -- of NPCs to spawn and the interval is calculated.
    function spawner.adapt_mg_villages_plotmarker(pos)
        -- Get the meta at the current position
        local meta = minetest.get_meta(pos)
        local village_id = meta:get_string("village_id")
        local plot_nr = meta:get_int("plot_nr")
        local infotext = meta:get_string("infotext")
        -- Check for nil values above
        if (not village_id or (village_id and village_id == ""))
                or (not plot_nr or (plot_nr and plot_nr == 0)) then
            return
        end

        local all_data = npc.places.get_mg_villages_building_data(pos)
        local building_data = all_data.building_data
        local building_type = all_data.building_type
        local building_pos_data = all_data.building_pos_dataS

        --minetest.log("Found building data: "..dump(building_data))

        -- Check if the building is of the support types
        for _,value in pairs(npc.spawner.mg_villages_supported_building_types) do

            if building_type == value then

                npc.log("INFO", "Replacing mg_villages:plotmarker at "..minetest.pos_to_string(pos))
                -- Store plotmarker metadata again
                meta:set_string("village_id", village_id)
                meta:set_int("plot_nr", plot_nr)
                meta:set_string("infotext", infotext)

                -- Store building type in metadata
                meta:set_string("building_type", building_type)
                -- Store plot information
                local plot_info = mg_villages.all_villages[village_id].to_add_data.bpos[plot_nr]
                plot_info["ysize"] = building_data.ysize
                -- minetest.log("Plot info at replacement time: "..dump(plot_info))
                meta:set_string("plot_info", minetest.serialize(plot_info))
                -- Scan building for nodes
                local nodedata = spawner.scan_mg_villages_building(pos, plot_info)
                -- Find building entrance
                local doors = nodedata.openable_type
                --minetest.log("Found "..dump(#doors).." openable nodes")
                local entrance = npc.places.find_entrance_from_openable_nodes(doors, pos)
                if entrance then
                    npc.log("INFO", "Found building entrance at: "..minetest.pos_to_string(entrance.node_pos))
                else
                    npc.log("ERROR", "Unable to find building entrance!")
                end
                -- Store building entrance
                meta:set_string("entrance", minetest.serialize(entrance))
                -- Store nodedata into the spawner's metadata
                meta:set_string("node_data", minetest.serialize(nodedata))
                -- Find nearby plotmarkers, excluding current plotmarker
                local nearby_plotmarkers = npc.places.find_plotmarkers(pos, 35, true)
                --minetest.log("Found nearby plotmarkers: "..dump(nearby_plotmarkers))
                meta:set_string("nearby_plotmarkers", minetest.serialize(nearby_plotmarkers))
                -- Check if building position data is also available (recent mg_villages)
                if building_pos_data then
                    meta:set_string("building_pos_data", minetest.serialize(building_pos_data))
                end
                -- Initialize NPCs
                local npcs = {}
                meta:set_string("npcs", minetest.serialize(npcs))
                -- Initialize NPC stats
                local npc_stats = {
                    male = {
                        total = 0,
                        adult = 0,
                        child = 0
                    },
                    female = {
                        total = 0,
                        adult = 0,
                        child = 0
                    },
                    adult_total = 0,
                    child_total = 0
                }
                meta:set_string("npc_stats", minetest.serialize(npc_stats))
                -- Set replaced
                meta:set_string("replaced", "true")
                -- Calculate how many NPCs will spawn
                npc.spawner.calculate_npc_spawning_on_plotmarker(pos)
                -- Stop searching for building type
                break
            end
        end
    end

    -- Node registration
    -- This node is currently a slightly modified mg_villages:plotmarker
    -- TODO: Change formspec to a more detailed one.
    minetest.override_item("mg_villages:plotmarker", {
        -- description = "Automatic NPC Spawner",
        -- drawtype = "nodebox",
        -- tiles = {"default_stone.png"},
        -- paramtype = "light",
        -- paramtype2 = "facedir",
        -- node_box = {
        --     type = "fixed",
        --     fixed = {
        --         {-0.5+2/16, -0.5, -0.5+2/16,  0.5-2/16, -0.5+2/16, 0.5-2/16},
        --         --{-0.5+0/16, -0.5, -0.5+0/16,  0.5-0/16, -0.5+0/16, 0.5-0/16},
        --     }
        -- },
        walkable = false,
        groups = {cracky=3,stone=2},

        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            -- NOTE: This is temporary code for testing...
            local nodedata = minetest.deserialize(minetest.get_meta(pos):get_string("node_data"))
            --minetest.log("Node data: "..dump(nodedata))
            --minetest.log("Entrance: "..dump(minetest.deserialize(minetest.get_meta(pos):get_string("entrance"))))
            --minetest.log("First-floor beds: "..dump(spawner.filter_first_floor_nodes(nodedata.bed_type, pos)))
            --local entrance = npc.places.find_entrance_from_openable_nodes(nodedata.openable_type, pos)
            --minetest.log("Found entrance: "..dump(entrance))
            minetest.log("Replaced: "..dump(minetest.get_meta(pos):get_string("replaced")))
            -- for i = 1, #nodedata.bed_type do
            -- 	nodedata.bed_type[i].owner = ""
            -- end
            -- minetest.get_meta(pos):set_string("node_data", minetest.serialize(nodedata))
            -- minetest.log("Cleared bed owners")
            --minetest.log("NPC stats: "..dump(minetest.deserialize(minetest.get_meta(pos):get_string("npc_stats"))))

            return mg_villages.plotmarker_formspec( pos, nil, {}, clicker )
        end,

        -- on_receive_fields = function(pos, formname, fields, sender)
        --   return mg_villages.plotmarker_formspec( pos, formname, fields, sender );
        -- end,

        on_timer = function(pos, elapsed)
            npc.spawner.spawn_npc_on_plotmarker(pos)
        end,

        -- protect against digging
        -- can_dig = function(pos, player)
        --   local meta = minetest.get_meta(pos);
        --   if (meta and meta:get_string("village_id") ~= "" and meta:get_int("plot_nr") and meta:get_int("plot_nr") > 0 ) then
        --       return false;
        --   end
        --   return true;
        -- end
    })

    -- LBM Registration
    -- Used to modify plotmarkers and replace them with advanced_npc:plotmarker_auto_spawner
    -- minetest.register_lbm({
    --   label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
    --   name = "advanced_npc:mg_villages_plotmarker_replacer",
    --   nodenames = {"mg_villages:plotmarker"},
    --   run_at_every_load = false,
    --   action = function(pos, node)
    --     -- Check if replacement is activated
    --     if npc.spawner.replace_activated then
    --       -- Replace mg_villages:plotmarker
    --       spawner.replace_mg_villages_plotmarker(pos)
    --       -- Set NPCs to spawn
    --       spawner.calculate_npc_spawning(pos)
    --     end
    --   end
    -- })

    -- ABM Registration
    minetest.register_abm({
        label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
        nodenames = {"mg_villages:plotmarker"},
        interval = 10,--npc.spawner.replacement_interval,
        chance = 1,--5,
        catch_up = true,
        action = function(pos, node, active_object_count, active_object_count_wider)
            -- Check if replacement is needed
            local meta = minetest.get_meta(pos)
            if meta then
                --   minetest.log("------ Plotmarker metadata -------")
                --   local plot_nr = meta:get_int("plot_nr")
                --   local village_id = meta:get_string("village_id")
                --   minetest.log("Plot nr: "..dump(plot_nr)..", village ID: "..dump(village_id))
                --   minetest.log(dump(mg_villages.get_plot_and_building_data( village_id, plot_nr )))
            end
            if minetest.get_meta(pos):get_string("replaced") == "true" then
                return
            end
            -- Check if replacement is activated
            if npc.spawner.replace_activated then
                -- Replace mg_villages:plotmarker
                spawner.adapt_mg_villages_plotmarker(pos)
            end
        end
    })

end

--minetest.register_alias_force("mg_villages:plotmarker", )

-- Chat commands to manage spawners
minetest.register_chatcommand("restore_plotmarkers", {
    description = "Replaces all advanced_npc:plotmarker_auto_spawner with mg_villages:plotmarker in the specified radius.",
    privs = {server=true},
    func = function(name, param)
        -- Check if radius is null
        if param == nil and type(param) ~= "number" then
            minetest.chat_send_player(name, "Need to enter a radius as an integer number. Ex. /restore_plotmarkers 10 for a radius of 10")
            return
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
        local start_pos = {x=pos.x - radius, y=pos.y - 5, z=pos.z - radius}
        local end_pos = {x=pos.x + radius, y=pos.y + 5, z=pos.z + radius}
        local nodes = minetest.find_nodes_in_area_under_air(start_pos, end_pos,
            {"mg_villages:plotmarker"})
        -- Check if we have nodes to replace
        minetest.chat_send_player(name, "Found "..dump(#nodes).." nodes to replace...")
        if #nodes == 0 then
            return
        end
        -- Replace all nodes
        for i = 1, #nodes do
            local meta = minetest.get_meta(nodes[i])
            local village_id = meta:get_string("village_id")
            local plot_nr = meta:get_int("plot_nr")
            local infotext = meta:get_string("infotext")
            local npcs = minetest.deserialize(meta:get_string("npcs"))
            -- Restore workplaces to original status
            if npcs then
                for i = 1, #npcs do
                    if npcs[i].workplace then
                        -- Remove work data
                        local workplace_meta = minetest.get_meta(npcs[i].workplace)
                        workplace_meta:set_string("work_data", nil)
                    end
                end
            end
            -- Set metadata
            meta = minetest.get_meta(nodes[i])
            meta:set_string("village_id", village_id)
            meta:set_int("plot_nr", plot_nr)
            meta:set_string("infotext", infotext)
            -- Clear NPC stats, NPC data and node data
            meta:set_string("node_data", nil)
            meta:set_string("npcs", nil)
            meta:set_string("npc_stats", nil)
            meta:set_string("replaced", "false")
        end
        minetest.chat_send_player(name, "Finished replacement of "..dump(#nodes).." auto-spawners successfully")
    end
})
