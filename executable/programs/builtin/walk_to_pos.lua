--
-- User: hfranqui
-- Date: 3/12/18
-- Time: 9:00 AM
--

-- This program can be used to make the NPC walk from one
-- position to another. If the optional parameter walkable_nodes
-- is included, which is a table of node names, these nodes are
-- going to be considered walkable for the algorithm to find a
-- path.
npc.programs.register("advanced_npc:walk_to_pos", function(self, args)
    -- Get arguments for this task
    local use_access_node = true
    if args.use_access_node ~= nil then
        use_access_node = args.use_access_node
    end
    local end_pos, node_pos = npc.programs.helper.get_pos_argument(self, args.end_pos, use_access_node)
    if end_pos == nil then
        npc.log("WARNING", "Got nil position in 'walk_to_pos' using args.pos: "..dump(args.end_pos))
        return
    end
    local enforce_move = args.enforce_move or true
    local optimize_one_node_distance = args.optimize_one_node_distance or true
    local walkable_nodes = args.walkable
    self.stepheight = 1.1
    self.object:set_properties(self)

    -- Round start_pos to make sure it can find start and end
    local start_pos = vector.round(self.object:getpos())

    -- Check if start_pos and end_pos are the same
    local distance = vector.distance(start_pos, end_pos)
    if distance < 0.75 then
        -- Check if it was using access node, if it was, rotate NPC into that direction
        if use_access_node == true and node_pos then
            local yaw = minetest.dir_to_yaw(vector.direction(end_pos, node_pos))
            npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE, {yaw = yaw})
        end
        npc.log("WARNING", "walk_to_pos Found start_pos == end_pos")
        return
    elseif distance >= 0.75 and distance < 2 then
        local yaw = minetest.dir_to_yaw(vector.direction(start_pos, end_pos))
        local target_pos = {x=end_pos.x, y=self.object:getpos().y, z=end_pos.z}
        -- Check if it is using access node
        if use_access_node == true and node_pos then
            -- Walk to end_pos, rotate to node_pos
            local final_yaw = minetest.dir_to_yaw(vector.direction(end_pos, node_pos))
            npc.programs.instr.execute(self, npc.programs.instr.default.WALK_STEP,
                {yaw = yaw, target_pos=target_pos})
            npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw=final_yaw})
        else
            -- Walk to end_pos
            npc.programs.instr.execute(self, npc.programs.instr.default.WALK_STEP,
                {yaw = yaw, target_pos=target_pos})
            npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {})
        end
        return
    else
        -- Set walkable nodes to empty if the parameter hasn't been used
        if walkable_nodes == nil then
            walkable_nodes = {}
        end

        -- Find path
        local path = npc.pathfinder.find_path(start_pos, end_pos, self, walkable_nodes)

        if path ~= nil and #path >= 1 then

            npc.log("INFO", "walk_to_pos Found path ("..dump(#path).." nodes) from "
                    ..minetest.pos_to_string(start_pos).." to: "..minetest.pos_to_string(end_pos))
            -- Add start pos to path
            table.insert(path, 1, {pos=start_pos, type=2})
            -- Store path
            self.npc_state.movement.walking.path = path

            -- Local variables
            local door_opened = false
            local steps_since_door_opened = 0
            local speed = npc.programs.const.speeds.two_nps_speed

            -- Set the command timer interval to half second. This is to account for
            -- the increased speed when walking.
            npc.programs.instr.execute(self, npc.programs.instr.default.SET_INTERVAL, {interval=0.5, freeze=true})

            -- Set the initial last and target positions
            --self.npc_state.movement.walking.target_pos = path[2].pos

            -- Add steps to path
            for i = 1, #path do

                -- Do not add an extra step if reached the goal node
                if (i+1) == #path then
                    -- Add direction to last node
                    local dir = vector.direction(path[i].pos, end_pos)
                    local yaw = minetest.dir_to_yaw(dir)
                    -- Add the last step
                    npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP,
                        {yaw = minetest.dir_to_yaw(dir), speed = speed, target_pos = path[i+1].pos})
                    -- Add stand animation at end
                    -- This is not the proper fix (and node_pos), but for now
                    -- it will avoid crashes
                    if use_access_node == true and node_pos then
                        --dir = npc.programs.helper.get_direction(end_pos, node_pos)
                        --minetest.log("end pos: "..dump(end_pos))
                        --minetest.log("Node pos: "..dump(node_pos))
                        yaw = minetest.dir_to_yaw(vector.direction(end_pos, node_pos))
                    end

                    -- If door is opened, close it
                    if door_opened then
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw=minetest.dir_to_yaw(vector.direction(path[i+1].pos, path[i].pos))})
                        -- Close door
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.USE_OPENABLE, {
                            pos=path[i].pos, command=npc.programs.const.node_ops.doors.command.CLOSE})
                        door_opened = false
                    end

                    -- Change dir if using access_node
                    npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw = yaw})
                    break
                end
                -- Get direction to move from path[i] to path[i+1]
                local dir = vector.direction(path[i].pos, path[i+1].pos)
                -- If a diagonal, increase speed by sqrt(2)
                if dir.x ~= 0 and dir.z ~=0 then
                    speed = speed * math.sqrt(2)
                end
                -- Check if next node is a door, if it is, open it, then walk
                if path[i+1].type == npc.pathfinder.node_types.openable then
                    -- Check if door is already open
                    local node = minetest.get_node(path[i+1].pos)
                    if npc.programs.helper.get_openable_node_state(node, path[i+1].pos,  dir)
                            == npc.programs.const.node_ops.doors.state.CLOSED then
                        --minetest.log("Opening command to open door")
                        -- Stop to open door, this avoids misplaced movements later on
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw=minetest.dir_to_yaw(dir)})
                        -- Open door
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.USE_OPENABLE,
                            {pos=path[i+1].pos, dir=dir, command=npc.programs.const.node_ops.doors.command.OPEN})

                        door_opened = true
                    end
                end

                -- Add walk command to command queue
                npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP,
                    {yaw = minetest.dir_to_yaw(dir), speed = speed, target_pos = path[i+1].pos})
                -- Restore speed to default
                speed = npc.programs.const.speeds.two_nps_speed
                -- Count the number of steps taken after opening a door
                if door_opened then
                    steps_since_door_opened = steps_since_door_opened + 1
                end

                if door_opened then
                    if steps_since_door_opened == 2 then
                        -- Stop to close door, this avoids misplaced movements later on
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw=minetest.dir_to_yaw(vector.direction(path[i+1].pos, path[i].pos))})
                        -- Close door
                        npc.exec.proc.enqueue(self, npc.programs.instr.default.USE_OPENABLE, {
                            pos=path[i].pos, command=npc.programs.const.node_ops.doors.command.CLOSE})
                        -- Reset values
                        steps_since_door_opened = 0
                        door_opened = false
                    end
                end
            end

            -- Return the command interval to default interval of 1 second
            -- By default, always freeze.
            npc.exec.proc.enqueue(self, npc.programs.instr.default.SET_INTERVAL, {interval=1})

        else
            -- Unable to find path
            npc.log("WARNING", "walk_to_pos Unable to find path. Teleporting to: "..minetest.pos_to_string(end_pos))
            -- Check if movement is enforced
            if enforce_move then
                -- Move to end pos
                self.object:moveto({x=end_pos.x, y=end_pos.y+1, z=end_pos.z})
            end
        end
    end
end)

