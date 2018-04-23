--
-- User: hfranqui
-- Date: 3/12/18
-- Time: 9:00 AM
--

-- This function makes the NPC lay or stand up from a sittable node. The
-- pos is the location of the sittable node, command can be lay or get up
npc.programs.register("advanced_npc:use_sittable", function(self, args)
    local pos = npc.programs.helper.get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_sittable' using args.pos: "..dump(args.pos))
        return
    end
    local action = args.action
    local enable_usage_marking = args.enable_usage_marking or true
    local node = minetest.get_node(pos)

    if action == npc.programs.const.node_ops.sittable.SIT then
        minetest.log("Sitting...")
        -- Calculate position depending on bench
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        if npc.programs.instr.nodes.sittable[node.name] == nil then
            npc.log("WARNING", "Couldn't find node def for sittable node for node: "..dump(node.name))
            return
        end
        local sit_pos = npc.programs.instr.nodes.sittable[node.name].get_sit_pos(pos, node.param2)
        -- Sit down on bench/chair/stairs
        npc.programs.instr.execute(self, npc.programs.instr.default.SIT, {pos=sit_pos, dir=(node.param2 + 2) % 4})
        if enable_usage_marking then
            -- Set place as used
            npc.locations.mark_place_used(pos, npc.locations.USE_STATE.USED)
        end
    else
        if self.npc_state.movement.is_sitting == false then
            npc.log("DEBUG_ACTION", "NPC "..self.npc_name.." attempted to get up from sit when it is not sitting.")
            return
        end
        -- Find empty areas around chair
        local dir = node.param2 + 2 % 4
        -- Default it to the current position in case it can't find empty
        -- position around sittable node. Weird
        local pos_out_of_sittable = pos
        local empty_nodes = npc.locations.find_node_orthogonally(pos, {"air"}, 0)
        if empty_nodes ~= nil and #empty_nodes > 0 then
            -- Get direction to the empty node
            dir = npc.programs.helper.get_direction(pos, empty_nodes[1].pos)
            -- Calculate position to get out of sittable node
            pos_out_of_sittable =
            {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
        end
        -- Stand
        npc.programs.instr.execute(self, npc.programs.instr.default.STAND, {pos=pos_out_of_sittable, dir=dir})
        minetest.log("Setting sittable at "..minetest.pos_to_string(pos).." as not used")
        if enable_usage_marking then
            -- Set place as unused
            npc.locations.mark_place_used(pos, npc.locations.USE_STATE.NOT_USED)
        end
    end

end)

