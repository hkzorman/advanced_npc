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
function npc.spawner.scan_area_for_spawn(start_pos, end_pos, player_name, spawn_pos)
    local result = {
        building_type = "",
        plot_info = {},
        entrance = {},
        node_data = {},
        npcs = {},
        npc_stats = {}
    }

    -- Set building_type
    result.building_type = "custom"
    -- Get min pos and max pos
    local minp, maxp = vector.sort(start_pos, end_pos)
    -- Set plot info
    result.plot_info = {
        -- TODO: Check this and see if it is accurate!
        xsize = maxp.x - minp.x,
        ysize = maxp.y - minp.y,
        zsize = maxp.z - minp.z,
        start_pos = start_pos,
        end_pos = end_pos
    }

    -- Scan building nodes
    -- Scan building for nodes
    local usable_nodes = npc.locations.scan_area_for_usable_nodes(start_pos, end_pos)
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
    elseif spawn_pos ~= nil then
        -- A spawn egg was used, assume it was spawned outside the building
        outside_pos = spawn_pos
    end
    -- Try to find entrance
    local entrance = npc.locations.find_building_entrance(usable_nodes.bed_type, outside_pos)
    if entrance then
        npc.log("INFO", "Found building entrance at: "..minetest.pos_to_string(entrance.door))
        -- Set building entrance
        result.entrance = entrance
    else
        npc.log("ERROR", "Unable to find building entrance!")
    end

    -- Set node_data
    result.node_data = usable_nodes

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
    result.npc_stats = npc_stats

    return result
end

---------------------------------------------------------------------------------------
-- Spawning functions
---------------------------------------------------------------------------------------
-- This function attempts to determine an occupation for an NPC given:
--   - The local building type (building NPC is spawning)
--   - The surrounding workplaces' building types
--   - The NPCs in the local building
-- Lo and behold! In this function lies a code monster, smelly, incomprehensible..
function npc.spawner.determine_npc_occupation(building_type, workplace_nodes, npcs)
    local surrounding_buildings_map = {}
    local current_building_map = {}
    local current_building_npc_occupations = {}
    local result = {}

    -- Get all occupation names in the current building
    for i = 1, #npcs do
        if not npc.utils.array_contains(current_building_npc_occupations, npcs[i].occupation) then
            table.insert(current_building_npc_occupations, npcs[i].occupations)
        end
    end
    -- Classify workplaces into local and surrounding
    for i = 1, #workplace_nodes do
        local workplace = workplace_nodes[i]
        if workplace.surrounding_workplace == true then
            table.insert(surrounding_buildings_map,
                {type=workplace.building_type, origin_building_type=building_type})
        else
            current_building_map[workplace.building_type] = workplace
        end
    end

    -- Get occupation names for the buildings
    local occupation_names = npc.occupations.get_for_building(
        building_type,
        surrounding_buildings_map
    )
    npc.log("INFO", "Found occupations: "..dump(occupation_names).."\nfor local building type: "
        ..dump(building_type).."\nAnd surrounding building types: "..dump(surrounding_buildings_map))

    -- Insert default occupation into result
    result[#result + 1] = {name=npc.occupations.basic_name, node={node_pos={}}}

    ---------------------------------------------------------------------------------------
    -- Determine occupation
    ---------------------------------------------------------------------------------------
    -- First of all, iterate through all names, discard the default basic occupation.
    -- Next, check if no-one in this builiding has this occupation name.
    -- Next, check if the workplace node has no data assigned to it.
    -- Finally, if not, return an table with the occupation name, and the selected
    -- workplace node.
    -- Note: Much more can be done here. This is a simplistic implementation,
    -- given this is already complicated enough. For example, existing NPCs' occupation
    -- can play a much more important role, not only taken in consideration for discarding.
    -- Beware: Incomprehensible code lies ahead
    for i = 1, #occupation_names do
        -- Check if this occupation name is the default occupation, and if it is, continue
        if occupation_names[i] ~= npc.occupations.basic_name then
            -- Check if someone already works on this
            if npc.utils.array_contains(current_building_npc_occupations, occupation_names[i]) == false then
                -- Check if someone else already has this occupation at the same workplace
                 -- Get building types from occupation
                local local_building_types =
                    npc.occupations.registered_occupations[occupation_names[i]].building_types or {}
                local surrounding_building_types =
                    npc.occupations.registered_occupations[occupation_names[i]].surrounding_building_types or {}

                if #workplace_nodes > 0 then
                    for j = 1, #workplace_nodes do
                        -- Attempt to match the occupation definition's local and surrounding types
                        -- to the workplace node's building type.
                        local local_building_match = false
                        local surrounding_building_match = false

                        -- Check if there is building_type match between the def's local
                        -- building_types and the current workplace node's building_type
                        if #local_building_types > 0 then
                            -- New matching algorithm
                            for i = 1, #occupation_names do
                                for j = 1, #local_building_types do
                                    if building_type == local_building_types[j] then
                                        npc.log("INFO", "Found suitable occupation: "..dump(result))
                                        -- Forget about workplace location - let NPC find it
                                        local_building_match = true
                                        result[#result + 1] = {name=occupation_names[i], node={}}
                                        break
                                    end
                                end
                            end
--                            local_building_match =
--                                npc.utils.array_contains(local_building_types, workplace_nodes[j].building_type)
                        end

                        -- Check if there is building_type match between the def's surrounding
                        -- building_types and the current workplace node's building_type
                        if #surrounding_building_types > 0 then
                            npc.log("DEBUG", "Scanning "..dump(#workplace_nodes).." plotmarkers for surrounding workplaces")
                            for k = 1, #surrounding_building_types do
                                if surrounding_building_types[k].type == workplace_nodes[j].building_type then
                                    surrounding_building_match = true
                                    break
                                end
                            end
                        end
                        -- Check if there was a match
                        if local_building_match == true or surrounding_building_match == true then
                            -- Match found, attempt to map this workplace node to the
                            -- current occupation. How? Well, if the workplace isn't being
                            -- used by another NPC, then, use it
                            local meta = minetest.get_meta(workplace_nodes[j].node_pos)
                            local worker_data = minetest.deserialize(meta:get_string("work_data") or "")
                            npc.log("DEBUG", "Found worker data: "..dump(worker_data))
                            -- If no worker data is found, then create it
                            if not worker_data then
                                npc.log("INFO", "Found suitable occupation and workplace: "..dump(result))
                                table.insert(result, {name=occupation_names[i], node=workplace_nodes[j]})
                            end
                        end
                    end
                else
                    -- Try to match building type with the occupation local building types
                    minetest.log("Building type: "..dump(building_type))
                    minetest.log("Occupation local building types: "..dump(local_building_types))
                    for i = 1, #occupation_names do
                        for j = 1, #local_building_types do
                            if building_type == local_building_types[j] then
                                npc.log("INFO", "Found suitable occupation: "..dump(result))
                                -- Forget about workplace location - let NPC find it
                                result[#result + 1] = {name=occupation_names[i], node={}}
                                break
                            end
                        end
                    end
                    minetest.log("Local building match after: "..dump(result))
                end
            end
        end
    end

    -- Determine result. Choose profession, how to do it?
    -- First, check previous NPCs' occupation.
    --  - If there is a NPC working at something, check the NPC count.
    --      - If count is less than three (only two NPCs), default_basic occupation.
    --      - If count is greater than two, assign any eligible occupation with 50% chance
    --  - If not NPC is working, choose an occupation that is not default_basic
    minetest.log("Current building occupations: "..dump(current_building_npc_occupations))
    minetest.log("Result #: "..dump(#result))
    minetest.log("Result: "..dump(result))
    if next(current_building_npc_occupations) ~= nil then
        for i = 1, #current_building_npc_occupations do
            if current_building_npc_occupations[i] ~= npc.occupations.basic_name then
                if #current_building_npc_occupations < 3 then
                    -- Choose basic default occupation
                    return result[1]
                elseif #current_building_npc_occupations > 2 then
                    -- Choose any occupation
                    return result[math.random(1, #result)]
                    end
                end
            end
    else
        -- Check how many occupation names we have
        if #result == 1 then
            -- Choose basic default occupation
            return result[1]
        elseif #result == 2 then
            -- Return other than the basic default
            return result[2]
        else
            -- Choose an occupation with equal chance each
            return result[math.random(2, #result)]
        end
    end
    -- By default, if nothing else works, return basic default occupation
    return result[1]
end

-- This function is called when the node timer for spawning NPC
-- is expired. Can be called manually by supplying either:
--   - Position of mg_villages plotmarker, or,
--   - position of custom building spawner
-- Prerequisite for calling this function is:
--  - In case of mg_villages, spawner.adapt_mg_villages_plotmarker(), or,
--  - in case of custom buildings, npc.spawner.scan_area_for_spawn()
function npc.spawner.spawn_npc_on_plotmarker(entity_name, pos)
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
                break
            end
        end
    end

    npc.log("INFO", "Attempting spawning of "..dump(entity_name).." at "..minetest.pos_to_string(pos))

    -- Spawn NPC
    local metadata = npc.spawner.spawn_npc(entity_name, pos, area_info, {occupation_name=occupation_data.name, occupation_workplace_pos=occupation_data.node.node_pos})
    if type(metadata) == "boolean" then
        return
    end
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
function npc.spawner.spawn_npc(entity_name, pos, area_info, npc_info)
    -- Get occupation data
    local occupation_name = npc_info.occupation_name
    local occupation_workplace_pos = npc_info.occupation_workplace_pos
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
        local ent = minetest.add_entity({x=pos.x, y=pos.y+1, z=pos.z}, entity_name)
        if ent and ent:get_luaentity() then
            ent:get_luaentity().initialized = false
            -- Determine NPC occupation - use given or default
            local occupation = occupation_name or "default_basic"
            -- Initialize NPC
            -- Call with stats if there are NPCs
            if npc_table and #npc_table > 0 then
                npc.initialize(ent, pos, false, npc_stats, npc_info)
            else
                npc.initialize(ent, pos, nil, nil, npc_info)
            end
            -- If node_data is present, assign nodes
            npc.log("DEBUG", "Node data: "..dump(node_data))
            if node_data then
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
                gender = ent:get_luaentity().gender,
                age = age,
                occupation = occupation,
                workplace = occupation_workplace_pos,
                born_day = minetest.get_day_count()
            }
            npc.log("DEBUG", "Area info: "..dump(area_info))
            table.insert(area_info.npcs, entry)
            -- Update and store stats
            -- Increase total of NPCs for specific gender
            npc_stats[ent:get_luaentity().gender].total =
            npc_stats[ent:get_luaentity().gender].total + 1
            -- Increase total number of NPCs by age
            npc_stats[age.."_total"] = npc_stats[age.."_total"] + 1
            -- Increase number of NPCs by age and gender
            npc_stats[ent:get_luaentity().gender][age] =
            npc_stats[ent:get_luaentity().gender][age] + 1
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
        npc.locations.add_shared(self, npc.locations.data.other.home_plotmarker,
            npc.locations.data.other.home_plotmarker, pos)
    end

    -- Assign building entrance door
    if entrance ~= nil and entrance.door ~= nil and entrance.inside ~= nil and entrance.outside ~= nil then
        npc.locations.add_shared(self, npc.locations.data.openable.home_entrance_door, npc.locations.data.openable.home_entrance_door, entrance.door)
        -- Assign these places to npc
        npc.locations.add_shared(self, npc.locations.data.other.home_inside, npc.locations.data.other.home_inside, entrance.inside)
        npc.locations.add_shared(self, npc.locations.data.other.home_outside, npc.locations.data.other.home_outside, entrance.outside)
    end

    -- Assign beds
    local assigned_bed
    if #node_data.bed_type > 0 then
        -- Assign a specific bed node to a NPC.
        assigned_bed = npc.locations.add_owned_accessible_place(self, node_data.bed_type,
            npc.locations.data.bed.primary)
    end

    -- Assign rooms
    if assigned_bed then
        local bedroom_entrance = npc.locations.find_bedroom_entrance(assigned_bed, pos)
        --minetest.log("Entrance: "..dump(bedroom_entrance))
        if bedroom_entrance ~= nil
                and bedroom_entrance.door ~= nil
                and bedroom_entrance.inside ~= nil
                and bedroom_entrance.outside ~= nil then
            npc.locations.add_shared(self, npc.locations.data.openable.room_entrance_door, npc.locations.data.openable.room_entrance_door, bedroom_entrance.door)
            -- Assign these places to npc
            npc.locations.add_shared(self, npc.locations.data.other.room_inside, npc.locations.data.other.room_inside, bedroom_entrance.inside)
            npc.locations.add_shared(self, npc.locations.data.other.room_outside, npc.locations.data.other.room_outside, bedroom_entrance.outside)
        end
    end

    -- Assign sits
    if #node_data.sittable_type > 0 then
        -- Check if there are same or more amount of sits as beds
        if #node_data.sittable_type >= #node_data.bed_type then
            -- Assign a specific sittable node to a NPC.
            npc.locations.add_owned_accessible_place(self, node_data.sittable_type,
                npc.locations.data.sittable.primary)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all sits to places as shared since NPC should be able to sit
        -- at any accessible sit
        npc.locations.add_shared_accessible_place(self, node_data.sittable_type,
            npc.locations.data.sittable.shared)
    end

    -- Assign furnaces
    if #node_data.furnace_type > 0 then
        -- Check if there are same or more amount of furnace as beds
        if #node_data.furnace_type >= #node_data.bed_type then
            -- Assign a specific furnace node to a NPC.
            npc.locations.add_owned_accessible_place(self, node_data.furnace_type,
                npc.locations.data.furnace.primary)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all furnaces to places as shared since NPC should be able to use
        -- any accessible furnace
        npc.locations.add_shared_accessible_place(self, node_data.furnace_type,
            npc.locations.data.furnace.shared)
    end

    -- Assign storage nodes
    if #node_data.storage_type > 0 then
        -- Check if there are same or more amount of storage as beds
        if #node_data.storage_type >= #node_data.bed_type then
            -- Assign a specific storage node to a NPC.
            npc.locations.add_owned_accessible_place(self, node_data.storage_type,
                npc.locations.data.storage.primary)
            -- Store changes to node_data
            --meta:set_string("node_data", minetest.serialize(node_data))
        end
        -- Add all storage-types to places as shared since NPC should be able
        -- to use other storaage nodes as well.
        npc.locations.add_shared_accessible_place(self, node_data.storage_type,
            npc.locations.data.storage.shared)
    end

    -- Assign workplace nodes
    -- Beware: More incomprehensibe code lies ahead!
    npc.log("INFO", "Assigning workplace node to NPC "..self.npc_name.." with occupation "..dump(self.occupation_name))
    if #node_data.workplace_type > 0 then
        npc.log("DEBUG", "Node Data workplace nodes: "..dump(node_data.workplace_type))
        -- First, find the workplace_node that was marked
        for i = 1, #node_data.workplace_type do
--            minetest.log("In assign places: workplace nodes: "..dump(node_data.workplace_type))
--            minetest.log("Condition? "..dump(node_data.workplace_type[i].occupation
--                    and node_data.workplace_type[i].occupation == self.occupation_name))
            if node_data.workplace_type[i].occupation
                    and node_data.workplace_type[i].occupation == self.occupation_name then
                npc.log("INFO", "Found a workplace node that is match to NPC occupation: "..dump(node_data.workplace_type[i]))
                -- Walkable nodes from occupation
                local walkables = npc.occupations.registered_occupations[self.occupation_name].walkable_nodes
                -- Found the node. Assign only this node to the NPC.
                npc.locations.add_shared_accessible_place(self, {node_data.workplace_type[i]},
                    npc.locations.data.workplace.primary, false, walkables)
                -- Edit metadata of this workplace node to not allow it for other NPCs
                local meta = minetest.get_meta(node_data.workplace_type[i].node_pos)
                local work_data = {
                    npc_name = self.npc_name,
                    occupation = self.occupation_name,
                    multiple_npcs =
                    npc.occupations.registered_occupations[self.occupation_name].allow_multiple_npcs_at_workplace
                }
                meta:set_string("work_data", minetest.serialize(work_data))
            end
        end
    end


    npc.log("DEBUG", "Places for NPC "..self.npc_name..": "..dump(self.places_map))

    -- Make NPC go into their house
    -- If entrance is available let NPC
    if entrance then
--        npc.enqueue_script(self,
--            npc.commands.cmd.WALK_TO_POS,
--            {end_pos=npc.locations.data.OTHER.HOME_INSIDE,
--                walkable={}})
--        npc.enqueue_command(self, npc.commands.cmd.FREEZE, {freeze = false})
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

-- This map holds the spawning position chosen by a player at a given time.
local spawner = {
    spawn_pos = {},
    entity_name = ""
}

-- Spawn egg (WIP)
-- Use for manually spawning NPCs. Up to now, supports local occupations only.
function npc.spawner.register_spawn_egg(entity_name)
    minetest.register_craftitem(entity_name.."_spawn_egg", {
        description = "NPC Spawner",
        inventory_image = "mobs_chicken_egg.png^(default_brick.png^[mask:mobs_chicken_egg_overlay.png)",
        on_place = function(itemstack, user, pointed_thing)
            -- Store spawn pos
            spawner.spawn_pos[user:get_player_name()] = pointed_thing.above
            -- This looks horrible - please change
            spawner.name = string.split(itemstack:get_name(), "_spawn_egg")[1]

            local occupation_names = npc.utils.get_map_keys(npc.occupations.registered_occupations)

            local building_dropdown_string = "dropdown[0.5,0.75;6;building_type;"
            for i = 1, #npc.spawner.mg_villages_supported_building_types do
                building_dropdown_string = building_dropdown_string
                        ..npc.spawner.mg_villages_supported_building_types[i]..","
            end
            building_dropdown_string = building_dropdown_string..";1]"

            -- Generate occupation dropdown
            local occupation_dropdown_string = "dropdown[0.5,1.95;6;occupation_name;"
            for i = 1, #occupation_names do
                occupation_dropdown_string = occupation_dropdown_string..occupation_names[i]..","
            end
            occupation_dropdown_string = occupation_dropdown_string..";1]"

            local formspec = "size[7,7]"..
                    "label[0.1,0.25;Building type]"..
                    building_dropdown_string..
                    "label[0.1,1.45;Occupation]"..
                    occupation_dropdown_string..
                    "field[0.5,3;3,2;radius;Search radius;20]"..
                    "field[3.5,3;3,2;height;Search height;2]"..
                    "button_exit[2.25,6.25;2.5,0.75;exit;Spawn]"

            minetest.show_formspec(user:get_player_name(), "advanced_npc:spawn_egg_main", formspec)
        end
    })
end

-- This map holds the name of the player and the position of the workplace that
-- he/she placed
spawner.workplace_pos = {}

-- Manual workplace marker (WIP)
-- Put this where a workplace for a NPC is. For example: in a cotton field,
-- inside a church, etc.
minetest.register_node("advanced_npc:workplace_marker", {
    description = "NPC Workplace Marker",
    tiles = {"default_stone.png"},
    paramtype = "light",
    paramtype2 = "facedir",
    drawtype = "nodebox",
    node_box = {
        type = "fixed",
        fixed = {
            {-0.5+2/16, -0.5, -0.5+2/16,  0.5-2/16, -0.5+3/16, 0.5-2/16},
        },
    },
    groups = {cracky=1},
    after_place_node = function(pos, placer, itemstack, pointed_thing)
        local meta = minetest.get_meta(pos)
        meta:set_string("infotext", "Unconfigured workplace marker")
    end,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        -- Read current value
        local meta = minetest.get_meta(pos)
        local building_type = meta:get_string("building_type") or ""
        local surrounding_workplace = meta:get_string("surrounding_workplace")
        -- Consider changing the field for a dropdown
        local formspec = "size[7,4]"..
                "label[0.1,0.25;Building type]"..
                "field[0.5,1;6.5,2;text;(farm_tiny, farm_full, house, church, etc.);"..building_type.."]"..
                "checkbox[0.5,2.25;is_surrounding;Is surrounding building;"
                ..surrounding_workplace.."]"..
                "button_exit[0.95,3.25;2.5,0.75;exit_btn;Proceed]"..
                "button_exit[3.5,3.25;2.5,0.75;reset_btn;Reset]"

        spawner.workplace_pos[clicker:get_player_name()] = pos

        minetest.show_formspec(clicker:get_player_name(), "advanced_npc:workplace_marker_formspec", formspec)
    end,
})

-- Handle formspecs
minetest.register_on_player_receive_fields(function(player, formname, fields)

    if formname then
        -- Handle spawn egg formspec
        if formname == "advanced_npc:spawn_egg_main" then
            if fields then
                -- Handle exit (spawn) button
                if fields.exit then
                    local pos = spawner.spawn_pos[player:get_player_name()]
                    local name = spawner.name
                    local radius = 20
                    local y_adj = 2
                    -- Set radius if present
                    if fields.radius then
                        radius = tonumber(fields.radius)
                    end
                    -- Set y adjustment if present
                    if fields.height then
                        y_adj = tonumber(fields.height)
                    end
                    -- Calculate positions
                    local start_pos = {x=pos.x-radius, y=pos.y-y_adj, z=pos.z-radius }
                    local end_pos = {x=pos.x+radius, y=pos.y+y_adj, z=pos.z+radius }

                    -- Scan for usable nodes
                    local area_info = npc.spawner.scan_area_for_spawn(start_pos, end_pos, player:get_player_name(), pos)
                    minetest.log("Area info: "..dump(area_info))
                    -- Assign occupation
                    local occupation_data = npc.spawner.determine_npc_occupation(
                        fields.building_type or area_info.building_type,
                        area_info.node_data.workplace_type,
                        area_info.npcs)

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
                    local metadata = npc.spawner.spawn_npc(name, pos, area_info, {occupation_name=fields.occupation_name})
                end
            end
        end
        -- Handle workplace marker formspec
        if formname == "advanced_npc:workplace_marker_formspec" then
            if fields then
                local pos = spawner.workplace_pos[player:get_player_name()]
                local meta = minetest.get_meta(pos)
                -- Checkbox setting
                if fields.is_surrounding then
                    --minetest.log("Saving.. "..fields.is_surrounding)
                    meta:set_string("surrounding_workplace", ""..fields.is_surrounding.."")
                end
                -- Handle reset button
                if fields.reset_btn then
                    meta:set_string("building_type", "")
                    meta:set_string("surrounding_workplace", false)
                    meta:set_string("infotext", "Unconfigured workplace marker")
                    meta:set_string("work_data", nil)
                    return
                end
                -- Handle set button
                if (pos and fields.text and fields.exit_btn)
                        or (fields.key_enter_field and fields.key_enter_field == "building_type")  then
                    local meta = minetest.get_meta(pos)
                    meta:set_string("building_type", fields.text)
                    meta:set_string("infotext", fields.text.." (workplace)")
                end
            end
        end
    end

end)


---------------------------------------------------------------------------------------
-- Support code for mg_villages mods
---------------------------------------------------------------------------------------
if minetest.get_modpath("mg_villages") ~= nil then
    local mg_villages_entity_name = ""
    function npc.spawner.set_mg_villages_entity_name(name)
        mg_villages_entity_name = name
    end

    -- This function creates a table of the scannable nodes inside
    -- a mg_villages building. It needs the plotmarker position for a start
    -- point and the building_data to get the x, y and z-coordinate size
    -- of the building schematic
    function spawner.scan_mg_villages_building(pos, building_data)
        local result = {}
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
        -- Attempt rotating the search area if no data is found
        for i = 1, 4 do
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

            result = npc.locations.scan_area_for_usable_nodes(start_pos, end_pos)
            if result and result.bed_type and #result.bed_type > 0 then
                -- Store start and end pos in plotmarker metadata for any future use
                local meta = minetest.get_meta(pos)
                meta:set_string("advanced_npc:area_pos1", minetest.serialize(start_pos))
                meta:set_string("advanced_npc:area_pos2", minetest.serialize(end_pos))
                meta:mark_as_private({"advanced_npc:area_pos1", "advanced_npc:area_pos2"})
                return result
            else
                npc.log("WARNING", "Failed attempt "..dump(i).." in finding usable nodes. "..dump(4-i).." attempts left.")
                -- Rotate search area and try again
                brotate = (brotate + 1) % 4
            end
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

        local all_data = npc.locations.get_mg_villages_building_data(pos)
        local building_data = all_data.building_data
        local building_type = all_data.building_type
        local building_pos_data = all_data.building_pos_dataS

        --minetest.log("bldng data: "..dump(building_data))
        --minetest.log("bldng type: "..dump(building_type))
        --minetest.log("Pos data: "..dump(building_pos_data))
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
                npc.log("DEBUG", "Plot info at replacement time: "..dump(plot_info))
                meta:set_string("plot_info", minetest.serialize(plot_info))
                -- Scan building for nodes
                local nodedata = spawner.scan_mg_villages_building(pos, plot_info)

                if not nodedata then
                    npc.log("ERROR", "Unable to find usable nodes in building.")
                    return
                end

                -- Find building entrance
                local doors = nodedata.openable_type
                --minetest.log("Found "..dump(#doors).." openable nodes")
                npc.log("DEBUG", "Nodedata: "..dump(nodedata))
                local entrance = npc.locations.find_building_entrance(nodedata.bed_type, pos)
                --minetest.log("Found good entrance: "..dump(entrance1))
                --local entrance = npc.locations.find_entrance_from_openable_nodes(doors, pos)
                if entrance then
                    npc.log("INFO", "Found building entrance at: "..minetest.pos_to_string(entrance.door))
                else
                    npc.log("ERROR", "Unable to find building entrance!")
                end
                -- Store building entrance
                meta:set_string("entrance", minetest.serialize(entrance))
                -- Store nodedata into the spawner's metadata
                meta:set_string("node_data", minetest.serialize(nodedata))
                -- Find nearby plotmarkers, excluding current plotmarker
                local nearby_plotmarkers = npc.locations.find_plotmarkers(pos, 40, true)
                --npc.log("INFO", "SPWNER: Found nearby plotmarkers: "..dump(nearby_plotmarkers))
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
    minetest.override_item("mg_villages:plotmarker", {
        walkable = false,
        groups = {cracky=3,stone=2},

        -- TODO: Change formspec to a more detailed one.
        on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
            local meta = minetest.get_meta(pos)
            minetest.log("NPCs: "..dump(minetest.deserialize(meta:get_string("npcs"))))
            minetest.log("Node data: "..dump(minetest.deserialize(meta:get_string("node_data"))))
            return mg_villages.plotmarker_formspec( pos, nil, {}, clicker )
        end,

        on_timer = function(pos, elapsed)
            -- Adds timer support
            if mg_villages_entity_name ~= nil and mg_villages_entity_name ~= "" then
                npc.spawner.spawn_npc_on_plotmarker(mg_villages_entity_name, pos)
            end
        end,
    })

    -- ABM Registration
    -- Consider changing this to be on nodetimer
    minetest.register_abm({
        label = "Replace mg_villages:plotmarker with Advanced NPC auto spawners",
        nodenames = {"mg_villages:plotmarker"},
        interval = 10,--npc.spawner.replacement_interval,
        chance = 1,--5,
        catch_up = true,
        action = function(pos, node, active_object_count, active_object_count_wider)
            -- Check if replacement is needed
            local meta = minetest.get_meta(pos)
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
            -- Clear node_data metadata
            local node_data = minetest.deserialize(meta:get_string("node_data"))
            npc.locations.clear_metadata_usable_nodes_in_area(node_data)

            meta:set_string("node_data", nil)
            meta:set_string("npcs", nil)
            meta:set_string("npc_stats", nil)
            meta:set_string("replaced", "false")
        end
        minetest.chat_send_player(name, "Finished replacement of "..dump(#nodes).." auto-spawners successfully")
    end
})

minetest.register_chatcommand("restore_area", {
    description = "",
    privs = {server = true},
    func = function(name, param)
        local args = npc.utils.split(param, " ")
        minetest.log("Params: "..dump(args))
        if #args < 2 then
            minetest.chat_send_player("Please specify horizontal and vertical radius.")
            return
        end
        local radius = args[1]
        local y_adj = args[2]
        -- Get player position
        local pos = {}
        for _,player in pairs(minetest.get_connected_players()) do
            if player:get_player_name() == name then
                pos = player:get_pos()
                break
            end
        end
        -- Search for nodes
        -- Calculate positions
        local start_pos = {x=pos.x-radius, y=pos.y-y_adj, z=pos.z-radius }
        local end_pos = {x=pos.x+radius, y=pos.y+y_adj, z=pos.z+radius }

        -- Scan for usable nodes
        local node_data = npc.locations.scan_area_for_usable_nodes(start_pos, end_pos)
        local removed_count = npc.locations.clear_metadata_usable_nodes_in_area(node_data)

        minetest.chat_send_player(name, "Restored "..dump(removed_count).." nodes in area from "
                ..minetest.pos_to_string(start_pos).." to "..minetest.pos_to_string(end_pos))
    end
})
