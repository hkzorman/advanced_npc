--
-- User: hfranqui
-- Date: 4/20/18
-- Time: 9:16 AM
-- Description: Node query program to replace scheduler check functionality
--

npc.programs.register("advanced_npc:node_query", function(self, args)

    local times_to_execute = args.count or 0
    local randomize_execution_count = args.randomize_execution_count
    local max_count = args.max_count
    local min_count = args.min_count
    local state_program_on_finished = args.state_program_on_finished
    local range = args.range
    local vertical_range_limit = args.vertical_range_limit or args.range
    local walkable_nodes = args.walkable_nodes
    local nodes = args.nodes
    local prefer_last_acted_upon_node = args.prefer_last_acted_upon_node
    local on_found_executables = args.on_found_executables
    local on_not_found_executables = args.on_not_found_executables

    -- Set random execution count to false if argument not provided
    if randomize_execution_count == nil then
        randomize_execution_count = false
    elseif randomize_execution_count == true then
        -- Calculate count if random
        times_to_execute = math.random(min_count, max_count)
    end

    -- Get NPC position
    local start_pos = self.object:getpos()
    -- Search nodes
    local found_nodes = npc.locations.find_node_nearby(start_pos, nodes, range, vertical_range_limit)
    -- Check if any node was found
    npc.log("DEBUG_SCHEDULE", "Found nodes using radius: "..dump(found_nodes))
    if found_nodes and #found_nodes > 0 then
        local node_pos
        local node
        local last_node_acted_upon = npc.exec.var.get(self, "last_node_acted_upon")
        -- Check if there is preference to act on nodes already acted upon
        if prefer_last_acted_upon_node == true and last_node_acted_upon then
            -- Find a node other than the acted upon - try 3 times
            for i = 1, #found_nodes do
                node_pos = found_nodes[i]
                -- Get node info
                node = minetest.get_node(node_pos)
                if node.name == last_node_acted_upon then
                    break
                end
            end
        else
            -- Create variable
            npc.exec.var.put(self, "last_node_acted_upon", "")
            -- Pick a random node to act upon
            node_pos = found_nodes[math.random(1, #found_nodes)]
            -- Get node info
            node = minetest.get_node(node_pos)
        end
        -- Save this node as the last acted upon
        npc.exec.var.set(self, "last_node_acted_upon", node.name)
        -- Set node as a place
        -- Note: Code below isn't *adding* a node, but overwriting the
        -- place with "schedule_target_pos" place type
        npc.log("DEBUG_SCHEDULE", "Found "..dump(node.name).." at pos: "..minetest.pos_to_string(node_pos))
        npc.locations.add_shared_accessible_place(
            self, {owner="", node_pos=node_pos}, npc.locations.data.calculated.target, true, walkable_nodes)
        -- Get actions related to node and enqueue them
        for i = 1, #on_found_executables[node.name] do
--            local args = {}
--            local action
--            -- Calculate arguments for the following supported actions:
--            --   - Dig
--            --   - Place
--            --   - Walk step
--            --   - Walk to position
--            --   - Use furnace
--            if actions[node.name][i].action == npc.commands.cmd.DIG then
--                -- Defaults: items will be added to inventory if not specified
--                -- otherwise, and protection will be respected, if not specified
--                -- otherwise
--                args = {
--                    pos = node_pos,
--                    add_to_inventory = actions[node.name][i].args.add_to_inventory or true,
--                    bypass_protection = actions[node.name][i].args.bypass_protection or false
--                }
--                npc.add_action(self, actions[node.name][i].action, args)
--            elseif actions[node.name][i].action == npc.commands.cmd.PLACE then
--                -- Position: providing node_pos is because the currently planned
--                -- behavior for placing nodes is replacing digged nodes. A NPC farmer,
--                -- for instance, might dig a plant node and plant another one on the
--                -- same position.
--                -- Defaults: items will be taken from inventory if existing,
--                -- if not will be force-placed (item comes from thin air)
--                -- Protection will be respected
--                args = {
--                    pos = actions[node.name][i].args.pos or node_pos,
--                    source = actions[node.name][i].args.source or npc.commands.take_from_inventory_forced,
--                    node = actions[node.name][i].args.node,
--                    bypass_protection =  actions[node.name][i].args.bypass_protection or false
--                }
--                --minetest.log("Enqueue dig action with args: "..dump(args))
--                npc.add_action(self, actions[node.name][i].action, args)
--            elseif actions[node.name][i].action == npc.commands.cmd.ROTATE then
--                -- Set arguments
--                args = {
--                    dir = actions[node.name][i].dir,
--                    start_pos = actions[node.name][i].start_pos
--                            or {x=start_pos.x, y=node_pos.y, z=start_pos.z},
--                    end_pos = actions[node.name][i].end_pos or node_pos
--                }
--                -- Enqueue action
--                npc.add_action(self, actions[node.name][i].action, args)
--            elseif actions[node.name][i].action == npc.commands.cmd.WALK_STEP then
--                -- Defaults: direction is calculated from start node to node_pos.
--                -- Speed is default wandering speed. Target pos is node_pos
--                -- Calculate dir if dir is random
--                local dir = npc.commands.get_direction(start_pos, node_pos)
--                minetest.log("actions: "..dump(actions[node.name][i]))
--                if actions[node.name][i].args.dir == "random" then
--                    dir = math.random(0,7)
--                elseif type(actions[node.name][i].args.dir) == "number" then
--                    dir = actions[node.name][i].args.dir
--                end
--                args = {
--                    dir = dir,
--                    speed = actions[node.name][i].args.speed or npc.commands.one_nps_speed,
--                    target_pos = actions[node.name][i].args.target_pos or node_pos
--                }
--                npc.add_action(self, actions[node.name][i].action, args)
--            elseif actions[node.name][i].task == npc.commands.cmd.WALK_TO_POS then
--                -- Optimize walking -- since distances can be really short,
--                -- a simple walk_step() action can do most of the times. For
--                -- this, however, we need to calculate direction
--                -- First of all, check distance
--                local distance = vector.distance(start_pos, node_pos)
--                if distance < 3 then
--                    -- Will do walk_step based instead
--                    if distance > 1 then
--                        args = {
--                            dir = npc.commands.get_direction(start_pos, node_pos),
--                            speed = npc.commands.one_nps_speed
--                        }
--                        -- Enqueue walk step
--                        npc.add_action(self, npc.commands.cmd.WALK_STEP, args)
--                    end
--                    -- Add standing action to look at node
--                    npc.add_action(self, npc.commands.cmd.STAND,
--                        {dir = npc.commands.get_direction(self.object:getpos(), node_pos)}
--                    )
--                else
--                    -- Set end pos to be node_pos
--                    args = {
--                        end_pos = actions[node.name][i].args.end_pos or node_pos,
--                        walkable = actions[node.name][i].args.walkable or walkable_nodes or {}
--                    }
--                    -- Enqueue
--                    npc.enqueue_script(self, actions[node.name][i].task, args)
--                end
--            elseif actions[node.name][i].task == npc.commands.cmd.USE_FURNACE then
--                -- Defaults: pos is node_pos. Freeze is true
--                args = {
--                    pos = actions[node.name][i].args.pos or node_pos,
--                    item = actions[node.name][i].args.item,
--                    freeze = actions[node.name][i].args.freeze or true
--                }
--                npc.enqueue_script(self, actions[node.name][i].task, args)
--            else
--                -- Action or task that is not supported for value calculation
--                npc.enqueue_schedule_action(self, actions[node.name][i])
--            end
            local executable = on_found_executables[node.name][i]
            --minetest.log("Executable["..dump(i).."]: "..dump(executable))
            if executable then
                if executable.is_state_program then
                    -- Set state program
                    npc.exec.set_state_program(self,
                        executable.program_name,
                        executable.arguments,
                        executable.interrupt_option)
                end
                -- Enqueue entry
                npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
                    new_program = executable.program_name,
                    new_args = executable.arguments,
                    interrupt_options = executable.interrupt_options}
                )
            end
        end

        --npc.log("DEBUG_SCHEDULE", "Actions queue: "..dump(self.actions.queue))
    else
        -- No nodes found, enqueue none_actions
        for i = 1, #on_not_found_executables do
            -- Add start_pos to none_actions
            --on_not_found_executables[i].args["start_pos"] = start_pos
            -- Enqueue actions
            --npc.add_action(self, none_actions[i].action, none_actions[i].args)
            npc.exec.enqueue_program(self,
                on_not_found_executables[i].program_name,
                on_not_found_executables[i].arguments,
                on_not_found_executables[i].interrupt_options)
        end

        -- No nodes found
        --npc.log("DEBUG_SCHEDULE", "Actions queue: "..dump(self.actions.queue))
    end

    if times_to_execute or (randomize_execution_count and max_count and min_count) then
        -- Increase execution count
        local execution_count = npc.exec.var.get(self, "execution_count")
        if execution_count == nil then
            execution_count = 0
            npc.exec.var.put(self, "execution_count", execution_count)
        end
        execution_count = execution_count + 1
        npc.exec.var.set(self, "execution_count", execution_count)

        -- Check if max number of executions was reached
        if execution_count > times_to_execute then
            if state_program_on_finished then
                npc.exec.set_state_program(self,
                    state_program_on_finished.program_name,
                    state_program_on_finished.arguments,
                    state_program_on_finished.interrupt_option)
            end
        end
    end
end)


---- Range: integer, radius in which nodes will be searched. Recommended radius is
----		  between 1-3
---- Nodes: array of node names
---- Actions: map of node names to entries {action=<action_enum>, args={}}.
----			Arguments can be empty - the check function will try to determine most
----			arguments anyways (like pos and dir).
----			Special node "any" will execute those actions on any node except the
----			already specified ones.
---- None-action: array of entries {action=<action_enum>, args={}}.
----				Will be executed when no node is found.
--function npc.schedule_check(self)
--	npc.log("DEBUG_SCHEDULE", "Prev Actions queue: "..dump(self.actions.queue))
--end
