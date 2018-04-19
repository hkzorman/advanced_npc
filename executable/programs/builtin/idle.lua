--
-- Created by IntelliJ IDEA.
-- Date: 3/8/18
-- Time: 6:34 PM
--

-- TODO: Implement whitelist
npc.programs.instr.register("advanced_npc:idle:acknowledge_objects", function(self, args)
    local obj_search_radius = args.obj_search_radius or 4
    local obj_whitelist = args.whitelist

    local objs = minetest.get_objects_inside_radius(self.object:getpos(), obj_search_radius)

    if #objs > 1 then
        for _,obj in pairs(objs) do
            if obj:is_player() or
                    (obj:get_luaentity() and obj:get_luaentity().npc_id and obj:get_luaentity().npc_id ~= self.npc_id) or
                    (obj:get_luaentity() and obj:get_luaentity().type == "animal") then
                -- Rotate NPC towards object
                local yaw = minetest.dir_to_yaw(vector.direction(self.object:getpos(), obj:getpos()))
                npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE, {yaw=yaw})
                return true
            end
        end
    end

    return false
end)


-- Idle state script. NPC stays still on this state.
-- It is possible for it to acknowledge other NPCs or players if
-- configured as arguments.
-- Arguments:
--   - `acknowledge_nearby_objs`: boolean. If true, will look for objects and
--     rotate towards them when close by.
--   - `obj_search_interval`: integer, interval in seconds to search for objects.
--      Default is 5
--   - `obj_search_radius`: integer, radius in nodes to search for objects.
--      Default is 5
npc.programs.register("advanced_npc:idle", function(self, args)
    local search_nearby_objs = args.acknowledge_nearby_objs
    local obj_search_interval = args.obj_search_interval or 5
    local obj_search_radius = args.obj_search_radius or 4
    local wander_chance = args.wander_chance or 30
    local max_wandering_radius = args.max_wandering_radius or 10

    -- Check if NPC is moving, if it is, stop.
    if npc.programs.helper.is_moving(self) then
        npc.programs.instr.execute(self, npc.programs.instr.default.STAND, {})
    end

    if search_nearby_objs == true then
        local objs_found = npc.programs.instr.execute(self, "advanced_npc:idle:acknowledge_objects", {
            obj_search_radius = obj_search_radius
        })

        if objs_found == true then
            -- Shorten interval to rotate accurately towards object
            --npc.programs.instr.execute(self, npc.programs.instr.default.SET_PROCESS_INTERVAL, {interval=0.5})
        else
            -- Calculate wandering chance
            local calculated_wander_chance = math.random(0, 100)
            if calculated_wander_chance < wander_chance then
                npc.log("INFO", "Switching to wander state")
                -- Change to wander state process with mostly default args
                npc.exec.set_state_program(self, "advanced_npc:wander", {
                    max_radius = max_wandering_radius,
                    idle_chance = 0,
                    acknowledge_nearby_objs = true
                }, {})
                return
            else
                -- Set interval
                npc.programs.instr.execute(self, "advanced_npc:wait", {time=5})
                --npc.programs.instr.execute(self, npc.programs.instr.default.SET_PROCESS_INTERVAL, {interval=obj_search_interval})
                minetest.log("No obj found")
            end
        end
    end
end)
