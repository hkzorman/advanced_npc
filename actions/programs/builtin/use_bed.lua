--
-- User: hfranqui
-- Date: 3/12/18
-- Time: 9:00 AM
--

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, command can be lay or get up
npc.programs.register("advanced_npc:use_bed", function(self, args)
    local pos = npc.programs.helper.get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_bed' using args.pos: "..dump(args.pos))
        return
    end
    local action = args.action
    local enable_usage_marking = args.enable_usage_marking or true
    local node = minetest.get_node(pos)
    --minetest.log(dump(node))
    local dir = minetest.facedir_to_dir(node.param2)

    if action == npc.programs.const.node_ops.beds.LAY then
        -- Get position
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        local bed_pos = npc.programs.instr.nodes.beds[node.name].get_lay_pos(pos, dir)
        -- Sit down on bed, rotate to correct direction
        npc.programs.instr.execute(self, npc.programs.instr.default.SIT, {pos=bed_pos, dir=(node.param2 + 2) % 4})
        -- Lay down
        npc.exec.proc.enqueue(self, npc.programs.instr.default.LAY, {})
        if enable_usage_marking then
            -- Set place as used
            npc.locations.mark_place_used(pos, npc.locations.USE_STATE.USED)
        end
    else
        -- Calculate position to get up
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        local bed_pos_y = npc.programs.instr.nodes.beds[node.name].get_lay_pos(pos, dir).y
        local bed_pos = {x = pos.x, y = bed_pos_y, z = pos.z}
        -- Sit up
        npc.programs.instr.execute(self, npc.programs.instr.default.SIT, {pos=bed_pos})
        -- Initialize direction: Default is front of bottom of bed
        local dir = (node.param2 + 2) % 4
        -- Find empty node around node
        -- Take into account that mats are close to the floor, so y adjustmen is zero
        local y_adjustment = -1
        if npc.programs.instr.nodes.beds[node.name].type == "mat" then
            y_adjustment = 0
        end

        local pos_out_of_bed = pos
        local empty_nodes = npc.locations.find_node_orthogonally(bed_pos, {"air", "cottages:bench"}, y_adjustment)
        if empty_nodes ~= nil and #empty_nodes > 0 then
            -- Get direction to the empty node
            dir = npc.programs.helper.get_direction(bed_pos, empty_nodes[1].pos)

            -- Calculate position to get out of bed
            pos_out_of_bed =
            {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
            -- Account for benches if they are present to avoid standing over them
            if empty_nodes[1].name == "cottages:bench" then
                pos_out_of_bed = {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
                if empty_nodes[1].param2 == 0 then
                    pos_out_of_bed.z = pos_out_of_bed.z - 0.3
                elseif empty_nodes[1].param2 == 1 then
                    pos_out_of_bed.x = pos_out_of_bed.x - 0.3
                elseif empty_nodes[1].param2 == 2 then
                    pos_out_of_bed.z = pos_out_of_bed.z + 0.3
                elseif empty_nodes[1].param2 == 3 then
                    pos_out_of_bed.x = pos_out_of_bed.x + 0.3
                end
            end

        end
        -- Stand out of bed
        npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {pos=pos_out_of_bed, dir=dir})
        if enable_usage_marking then
            -- Set place as unused
            npc.locations.mark_place_used(pos, npc.locations.USE_STATE.NOT_USED)
        end
    end
end)

