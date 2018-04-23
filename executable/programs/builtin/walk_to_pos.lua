--
-- User: hfranqui
-- Date: 3/12/18
-- Time: 9:00 AM
--

-- This function can be used to make the NPC walk from one
-- position to another. If the optional parameter walkable_nodes
-- is included, which is a table of node names, these nodes are
-- going to be considered walkable for the algorithm to find a
-- path.
npc.programs.register("advanced_npc:walk_to_pos", function(self, args)
    --minetest.log("Received arguments: "..dump(args))
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
    local walkable_nodes = args.walkable

    -- Round start_pos to make sure it can find start and end
    local start_pos = vector.round(self.object:getpos())
    npc.log("DEBUG", "walk_to_pos: Start pos: "..minetest.pos_to_string(start_pos))
    npc.log("DEBUG", "walk_to_pos: End pos: "..minetest.pos_to_string(end_pos))

    -- Check if start_pos and end_pos are the same
    if vector.equals(start_pos, end_pos) == true then
        -- Check if it was using access node, if it was, add command to
        -- rotate NPC into that direction
        if use_access_node == true then
            local dir = npc.programs.helper.get_direction(end_pos, node_pos)
            npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {dir = dir})
        end
        npc.log("WARNING", "walk_to_pos Found start_pos == end_pos")
        return
    end


    -- Set walkable nodes to empty if the parameter hasn't been used
    if walkable_nodes == nil then
        walkable_nodes = {}
    end

    -- Find path
    local path = npc.pathfinder.find_path(start_pos, end_pos, self, true)

    if path ~= nil and #path > 1 then
        npc.log("INFO", "walk_to_pos Found path to node: "..minetest.pos_to_string(end_pos))
        -- Store path
        self.npc_state.movement.walking.path = path

        -- Local variables
        local door_opened = false
        local speed = npc.programs.instr.two_nps_speed

        -- Set the command timer interval to half second. This is to account for
        -- the increased speed when walking.
        npc.exec.proc.enqueue(self, npc.programs.instr.default.SET_INTERVAL, {interval=0.5, freeze=true})

        -- Set the initial last and target positions
        self.npc_state.movement.walking.target_pos = path[1].pos

        -- Add steps to path
        for i = 1, #path do
            -- Do not add an extra step if reached the goal node
            if (i+1) == #path then
                -- Add direction to last node
                local dir = npc.programs.helper.get_direction(path[i].pos, end_pos)
                -- Add the last step
                npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP,
                    {dir = dir, speed = speed, target_pos = path[i+1].pos})
                -- Add stand animation at end
                if use_access_node == true then
                    --dir = npc.programs.helper.get_direction(end_pos, node_pos)
                    dir = minetest.dir_to_yaw(vector.direction(end_pos, node_pos))
                end
                --minetest.log("Dir: "..dump(dir))
                -- Change dir if using access_node
                npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {yaw = dir})
                break
            end
            -- Get direction to move from path[i] to path[i+1]
            local dir = npc.programs.helper.get_direction(path[i].pos, path[i+1].pos)
            -- Check if next node is a door, if it is, open it, then walk
            if path[i+1].type == npc.pathfinder.node_types.openable then
                -- Check if door is already open
                local node = minetest.get_node(path[i+1].pos)
                if npc.programs.helper.get_openable_node_state(node, path[i+1].pos,  dir)
                        == npc.programs.const.node_ops.doors.state.CLOSED then
                    --minetest.log("Opening command to open door")
                    -- Stop to open door, this avoids misplaced movements later on
                    npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {dir=dir})
                    -- Open door
                    npc.exec.proc.enqueue(self, npc.programs.instr.default.USE_OPENABLE,
                        {pos=path[i+1].pos, dir=dir, command=npc.programs.const.node_ops.doors.command.OPEN})

                    door_opened = true
                end

            end

            -- Add walk command to command queue
            npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP,
                {dir = dir, speed = speed, target_pos = path[i+1].pos})

            if door_opened then
                -- Stop to close door, this avoids misplaced movements later on
                -- local x_adj, z_adj = 0, 0
                -- if dir == 0 then
                -- 	z_adj = 0.1
                -- elseif dir == 1 then
                -- 	x_adj = 0.1
                -- elseif dir == 2 then
                -- 	z_adj = -0.1
                -- elseif dir == 3 then
                -- 	x_adj = -0.1
                -- end
                -- local pos_on_close = {x=path[i+1].pos.x + x_adj, y=path[i+1].pos.y + 1, z=path[i+1].pos.z + z_adj}
                -- Add extra walk step to ensure that one is standing at other side of openable node
                -- npc.enqueue_command(self, npc.commands.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+2].pos})
                -- Stop to close the door
                npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {dir=(dir + 2) % 4 })
                -- Close door
                npc.exec.proc.enqueue(self, npc.programs.instr.default.USE_OPENABLE, {
                    pos=path[i+1].pos, command=npc.programs.const.node_ops.doors.command.CLOSE})

                door_opened = false
            end
        end

        -- Return the command interval to default interval of 1 second
        -- By default, always freeze.
        npc.exec.proc.enqueue(self, npc.programs.instr.default.SET_INTERVAL, {interval=1, freeze=true})

    else
        -- Unable to find path
        npc.log("WARNING", "walk_to_pos Unable to find path. Teleporting to: "..minetest.pos_to_string(end_pos))
        -- Check if movement is enforced
        if enforce_move then
            -- Move to end pos
            self.object:moveto({x=end_pos.x, y=end_pos.y+1, z=end_pos.z})
        end
    end
end)

