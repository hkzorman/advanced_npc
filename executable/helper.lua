--
-- User: hfranqui
-- Date: 3/8/18
-- Time: 2:41 PM
--

npc.programs.const = {
    dir_data = {
        -- North
        [0] = {
            yaw = 0,
            vel = {x=0, y=0, z=1}
        },
        -- East
        [1] = {
            yaw = (3 * math.pi) / 2,
            vel = {x=1, y=0, z=0}
        },
        -- South
        [2] = {
            yaw = math.pi,
            vel = {x=0, y=0, z=-1}
        },
        -- West
        [3] = {
            yaw = math.pi / 2,
            vel = {x=-1, y=0, z=0}
        },
        -- North east
        [4] = {
            yaw = (7 * math.pi) / 4,
            vel = {x=1, y=0, z=1}
        },
        -- North west
        [5] = {
            yaw = math.pi / 4,
            vel = {x=-1, y=0, z=1}
        },
        -- South east
        [6] = {
            yaw = (5 * math.pi) / 4,
            vel = {x=1, y=0, z=-1}
        },
        -- South west
        [7] = {
            yaw = (3 * math.pi) / 4,
            vel = {x=-1, y=0, z=-1}
        }
    },
    node_ops = {
        doors = {
            command = {
                OPEN = 1,
                CLOSE = 2
            },
            state = {
                OPEN = 1,
                CLOSED = 2
            }
        },
        beds = {
            LAY = 1,
            GET_UP = 2
        },
        sittable = {
            SIT = 1,
            GET_UP = 2
        }
    },
    speeds = {
        one_nps_speed = 1,
        one_half_nps_speed = 1.5,
        two_nps_speed = 2
    },
    place_src = {
        take_from_inventory = "take_from_inventory",
        take_from_inventory_forced = "take_from_inventory_forced",
        force_place = "force_place"
    },
    craft_src = {
        take_from_inventory = "take_from_inventory",
        take_from_inventory_forced = "take_from_inventory_forced",
        force_craft = "force_craft"
    }
}

npc.programs.helper = {}

-- Helper functions
-- This function returns the direction enum
-- for the moving from v1 to v2
function npc.programs.helper.get_direction(v1, v2)
    local vector_dir = vector.direction(v1, v2)
    local dir = vector.round(vector_dir)

    if dir.x ~= 0 and dir.z ~= 0 then
        if dir.x > 0 and dir.z > 0 then
            return npc.direction.north_east
        elseif dir.x > 0 and dir.z < 0 then
            return npc.direction.south_east
        elseif dir.x < 0 and dir.z > 0 then
            return npc.direction.north_west
        elseif dir.x < 0 and dir.z < 0 then
            return npc.direction.south_west
        end
    elseif dir.x ~= 0 and dir.z == 0 then
        if dir.x > 0 then
            return npc.direction.east
        else
            return npc.direction.west
        end
    elseif dir.z ~= 0 and dir.x == 0 then
        if dir.z > 0 then
            return npc.direction.north
        else
            return npc.direction.south
        end
    end
end

-- This function allows to move into directions that are walkable. It
-- avoids fences and allows to move on plants.
-- This will make for nice wanderings, making the NPC move smartly instead
-- of just *oftenly* getting stuck at places... note that this will *NOT*
-- completely avoid the NPC being stuck
function npc.programs.helper.random_dir(start_pos, speed, dir_start, dir_end)
    --
    local bad_dirs = {}
    --minetest.log("Args: "..dump(start_pos)..", "..dump(speed)..","..dump(dir_start)..", "..dump(dir_end))
    -- Limit the number of tries - otherwise it could become an infinite loop
    for i = 1, 8 do
        local dir = math.random(dir_start, dir_end)
        if (bad_dirs[dir] == false) then
            -- Found dir that was known as bad, try dir + 1 until not
            -- found or greater than dir_end
            local good_found = false
            for j = dir_start, dir_end do
                dir = dir + 1
                if bad_dirs[dir] == nil then
                    break
                end
            end
            if good_found == false then
                return -1
            end
        end

        -- Find out if there are walkable nodes in the path ahead
        local vel = vector.multiply(npc.programs.const.dir_data[dir].vel, speed)
        local pos = vector.add(start_pos, vel)
        local node_below = minetest.get_node(vector.round(pos))
        local node_above = minetest.get_node(vector.round({x=pos.x,y=pos.y+1,z=pos.z}))

        if node_below and node_above then
            if npc.locations.is_walkable(node_below.name) and npc.locations.is_walkable(node_above.name) then
                return dir
            else
                bad_dirs[dir] = false
            end
        end
    end
    -- Return -1 signaling that no good direction could be found
    return -1
end

-- TODO: Refactor this function so that it uses a table to check
-- for doors instead of having separate logic for each door type
function npc.programs.helper.get_openable_node_state(node, pos, npc_dir)
    --minetest.log("Node name: "..dump(node.name))
    local state = npc.programs.const.node_ops.doors.state.CLOSED
    -- Check for MTG doors and gates
    local mtg_door_closed = false
    if minetest.get_item_group(node.name, "door") > 0 then
        local back_pos = vector.add(pos, minetest.facedir_to_dir(node.param2))
        local back_node = minetest.get_node(back_pos)
        if back_node.name == "air" or minetest.registered_nodes[back_node.name].walkable == false then
            mtg_door_closed = true
        end
    end
    -- Check for cottages gates
    local open_i1, open_i2 = string.find(node.name, "_close")
    -- Check for cottages half door
    local half_door_is_closed = false
    if node.name == "cottages:half_door" then
        half_door_is_closed = (node.param2 + 2) % 4 == npc_dir
    end
    if mtg_door_closed == false and open_i1 == nil and half_door_is_closed == false then
        state = npc.programs.const.node_ops.doors.state.OPEN
    end
    --minetest.log("Door state: "..dump(state))
    return state
end

-- Can receive a position argument in different formats
-- TODO: Document formats
function npc.programs.helper.get_pos_argument(self, pos, use_access_node)
--    minetest.log("Type of pos: "..dump(type(pos)))
--    minetest.log("Pos: "..dump(pos))
    -- Check which type of position argument we received
    if type(pos) == "table" then
        --minetest.log("Received table pos: "..dump(pos))
        -- Check if table is position
        if pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
            -- Position received, return position
            return pos
        elseif pos.place_type ~= nil then
            -- Received table in the following format:
            -- {
            -- 		place_category = "",
            -- 		place_type = "",
            -- 		index = 1,
            -- 		use_access_node = false|true,
            -- 		try_alternative_if_used = true|false
            -- }
            local index = pos.index or 1
            local use_access_node = pos.use_access_node or false
            local try_alternative_if_used = pos.try_alternative_if_used or false
            local places = npc.locations.get_by_type(self, pos.place_type)
            minetest.log("Place type: "..dump(pos.place_type))
            minetest.log("Places: "..dump(places))
            -- Check index is valid on the places map
            if #places >= index then
                local place = places[index]
                -- Check if place is used, and if it is, find alternative if required
                if try_alternative_if_used == true then
                    minetest.log("Self places map: "..dump(self.places_map))
                    minetest.log("Place category: "..dump(pos.place_category))
                    minetest.log("Place type: "..dump(pos.place_type))
                    minetest.log("Original Place: "..dump(place))
                    place = npc.locations.find_unused_place(self, pos.place_category, pos.place_type, place)
                    minetest.log("New place: "..dump(place))

                    if next(place) ~= nil then
                        --minetest.log("Mark as used? "..dump(pos.mark_target_as_used))
                        if pos.mark_target_as_used == true then
                            --minetest.log("Marking as used: "..minetest.pos_to_string(place.pos))
                            npc.locations.mark_place_used(place.pos, npc.locations.USE_STATE.USED)
                        end

                        npc.locations.add_shared_accessible_place(
                            self, {owner="", node_pos=place.pos}, npc.locations.data.calculated.target, true, {})
                    else
                        return nil
                    end
                end
                -- Check if access node is desired
                if use_access_node == true then
                    -- Return actual node pos
                    return place.access_node, place.pos
                else
                    -- Return node pos that allows access to node
                    return place.pos
                end
            end
        end
    elseif type(pos) == "string" then
        --npc.log("INFO", "Places map: "..dump(self.places_map))
        -- Received name of place, so we are going to look for the actual pos
        local places_pos = npc.locations.get_by_type(self, pos, false)
        --npc.log("INFO", "FOUND: "..dump(places_pos))
        -- Return nil if no position found
        if places_pos == nil or #places_pos == 0 then
            return nil
        end
        -- Check if received more than one position
        if #places_pos > 1 then
            -- Check all places, return owned if existent, else return the first one
            for i = 1, #places_pos do
                if places_pos[i].status == "owned" then
                    if use_access_node == true then
                        return places_pos[i].access_node, places_pos[i].pos
                    else
                        return places_pos[i].pos
                    end
                end
            end
        end
        -- Return the first position only if it couldn't find an owned
        -- place, or if it there is only one
        if use_access_node == true then
            return places_pos[1].access_node, places_pos[1].pos
        else
            return places_pos[1].pos
        end
    end
end

-- Helper function to determine if a NPC is moving
function npc.programs.helper.is_moving(self)
    return math.abs(vector.length(self.object:getvelocity())) > 0
end

-- Leave this for now as it might be useful
--npc.commands.register_script("advanced_npc:optimized_walk_to_pos", function(self, args)
--    local start_pos = self.object:getpos()
--    local end_pos = args.end_pos
--    local walkable_nodes = args.walkable_nodes or {}
--    -- Optimized walking -- since distances can be really short,
--    -- a simple walk_step() action can do most of the times. For
--    -- this, however, we need to calculate direction
--    -- First of all, check distance
--    local distance = vector.distance(start_pos, end_pos)
--    if distance < 3 then
--        -- Will do walk_step based instead
--        if distance > 1 then
--            args = {
--                dir = npc.commands.get_direction(start_pos, end_pos),
--                speed = npc.programs.const.speeds.one_nps_speed
--            }
--            -- Enqueue walk step
--            npc.enqueue_command(self, npc.commands.cmd.WALK_STEP, args)
--        end
--        -- Add standing action to look at end_pos
--        npc.enqueue_command(self, npc.commands.cmd.STAND,
--            {dir = npc.commands.get_direction(self.object:getpos(), end_pos)}
--        )
--    else
--        -- Set proper use_access_node param
--        --        local use_access_node = true
--        --        if args.use_access_node ~= nil then
--        --            use_access_node = args.use_access_node
--        --        end
--        --        local new_args = {
--        --            end_pos = end_pos,
--        --            walkable = walkable_nodes,
--        --            use_access_node = use_access_node
--        --        }
--        --        -- Enqueue
--        --        npc.enqueue_script(self, "advanced_npc:walk_to_pos", new_args)
--        local walk_args = {
--            dir = npc.commands.get_direction(start_pos, end_pos),
--            speed = npc.commands.one_nps_speed
--        }
--        -- Enqueue walk step
--        npc.enqueue_command(self, npc.commands.cmd.WALK_STEP, walk_args)
--    end
--end)



