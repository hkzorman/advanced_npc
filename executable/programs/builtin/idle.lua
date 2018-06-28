--
-- Created by IntelliJ IDEA.
-- Date: 3/8/18
-- Time: 6:34 PM
--

-- Register callback - count number of rightclick interactions
npc.monitor.callback.register("interactions_since_ack", "interaction", "on_rightclick", function(self)
    local interaction_count_since_ack =
        npc.data.get_or_put_if_nil(self, "interaction_count_since_ack", 0)
    npc.data.set(self, "interaction_count_since_ack", interaction_count_since_ack + 1)
end)

-- Timer for stopping acknowledge of nearby objects if no interactions
npc.monitor.timer.register("advanced_npc:idle:acknowledge_burnout", 5, function(self, args)
    -- Check if timer should run
    if self.execution.state_process.program_name ~= "advanced_npc:idle"
            and self.execution.state_process.program_name ~= "advanced_npc:wander"
            or self.execution.state_process.arguments.acknowledge_nearby_objs == false then
        -- Stop current timer
        npc.monitor.timer.stop(self, "advanced_npc:idle:acknowledge_burnout")
        return
    end

    -- Get number of interactions
    local interaction_count_since_ack = npc.data.get(self, "interaction_count_since_ack")
    -- Check if there has been any interaction
    if interaction_count_since_ack == 0 or interaction_count_since_ack == nil then
        -- Stop current timer
        npc.monitor.timer.stop(self, "advanced_npc:idle:acknowledge_burnout")
        -- Activate burnout reversal timer
        npc.monitor.timer.start(self, "advanced_npc:idle:burnout_reversal", args.reversal_timeout or 5, args)
        -- Change to wander state
        npc.exec.set_state_program(self, "advanced_npc:wander", {
            idle_chance = 0,
            acknowledge_nearby_objs = false
        }, {})
    else
        -- Reset interaction count
        npc.data.set(self, "interaction_count_since_ack", 0)
    end
end)

-- Timer to start acknowledging again
npc.monitor.timer.register("advanced_npc:idle:burnout_reversal", 5, function(self, args)
    -- Check if timer should run
    if self.execution.state_process.program_name ~= "advanced_npc:idle"
            and self.execution.state_process.program_name ~= "advanced_npc:wander"
            or self.execution.state_process.arguments.acknowledge_nearby_objs == false then
        -- Stop current timer
        npc.monitor.timer.stop(self, "advanced_npc:idle:burnout_reversal")
        return
    end
    -- Stop burnot timer and burnout reversal
    npc.monitor.timer.stop(self, "advanced_npc:idle:burnout_reversal")
    -- Signal instruction to restart acknowldge burnout
    npc.exec.var.set(self, "start_acknowledge_burnout", true)
    -- Change to wander state with acknowledge true
    npc.exec.set_state_program(self, "advanced_npc:idle", {
        acknowledge_nearby_objs = true
    }, {})
end)


-- TODO: Implement whitelist
npc.programs.instr.register("advanced_npc:idle:acknowledge_objects", function(self, args)
    local obj_search_radius = args.obj_search_radius or 4
    local acknowledge_burnout = args.acknowledge_burnout or 0
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
                -- Check if we have to activate timer to stop acknowledging
                if acknowledge_burnout > 0 then
                    local start_timer = npc.exec.var.get_or_put_if_nil(self, "start_acknowledge_burnout", true)
                    if start_timer == true then
                        npc.exec.var.set(self, "start_acknowledge_burnout", false)
                        -- Activate burnout timer
                        npc.monitor.timer.start(self,
                            "advanced_npc:idle:acknowledge_burnout",
                            acknowledge_burnout,
                            {reversal_timeout = acknowledge_burnout})
                    end

                end
                -- Object found
                return true
            end
        end
    end
    -- Object not found
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
    local max_acknowledge_time = args.max_acknowledge_time

    -- Check if NPC is moving, if it is, stop.
    if npc.programs.helper.is_moving(self) then
        npc.programs.instr.execute(self, npc.programs.instr.default.STAND, {})
    end

    local objs_found = false
    if search_nearby_objs == true then
        -- Search nearby objects and acknowledge them
        objs_found = npc.programs.instr.execute(self, "advanced_npc:idle:acknowledge_objects", {
            obj_search_radius = obj_search_radius,
            acknowledge_burnout = max_acknowledge_time
        })

        -- if objs_found == true then
        --     -- Shorten interval to rotate accurately towards object
        --     --npc.programs.instr.execute(self, npc.programs.instr.default.SET_PROCESS_INTERVAL, {interval=0.5})
        -- else
        
        -- end
    else
        -- Stop all acknowledging timers
        npc.monitor.timer.stop(self, "advanced_npc:idle:acknowledge_burnout")
        npc.monitor.timer.stop(self, "advanced_npc:idle:burnout_reversal")
    end

    -- Calculate wandering chance
    if objs_found == false then
        local calculated_wander_chance = math.random(0, 100)
        if calculated_wander_chance < wander_chance then
            npc.log("INFO", "Switching to wander state")
            -- Change to wander state process with mostly default args
            npc.exec.set_state_program(self, "advanced_npc:wander", {
                max_radius = max_wandering_radius,
                idle_chance = 0,
                acknowledge_nearby_objs = search_nearby_objs
            }, {})
            return
        else
            -- Set interval
            npc.programs.instr.execute(self, "advanced_npc:wait", {time=5})
            --npc.programs.instr.execute(self, npc.programs.instr.default.SET_PROCESS_INTERVAL, {interval=obj_search_interval})
            minetest.log("No obj found")
        end
    end
end)
