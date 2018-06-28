--
-- User: hfranqui
-- Date: 4/6/18
-- Time: 9:18 AM
-- Description: Wander program for Advanced NPC
--

-- Chance is a number from 0 to 100, indicates the chance
-- a NPC will have of walking one step on a random direction
npc.programs.register("advanced_npc:wander", function(self, args)
    local acknowledge_nearby_objs = args.acknowledge_nearby_objs
    local max_acknowledge_time = args.max_acknowledge_time
    local obj_search_radius = args.obj_search_radius or 3
    local chance = args.chance or 60
    local max_radius = args.max_radius or 10
    local speed = args.speed or npc.programs.const.speeds.one_nps_speed
    local idle_chance = args.idle_chance or 10

    -- First check if there's any object to acknowledge
    local objs_found = false
    if acknowledge_nearby_objs == true then
        objs_found = npc.programs.instr.execute(self, "advanced_npc:idle:acknowledge_objects", {
            obj_search_radius = obj_search_radius,
            acknowledge_burnout = max_acknowledge_time
        })
    end
    -- Check if there was any object found
    if objs_found == false then
        -- No object found, proceed to wander
        -- Calculate chance of walking
        local calculated_chance = math.random(0, 100)
        if calculated_chance < chance then
            -- Store initial position
            local init_pos = npc.exec.var.get(self, "init_pos")
            if init_pos == nil then
                init_pos = vector.round(self.object:getpos())
                npc.exec.var.put(self, "init_pos", init_pos)
            end
            -- Check if NPC has reached its maximum wandering radius
            if vector.distance(init_pos, self.object:getpos()) >= max_radius then

                --minetest.log("Walking back")

                -- Walk back to the initial position
                npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP, {
                    yaw = minetest.dir_to_yaw(vector.direction(self.object:getpos(), init_pos)),
                    speed = speed
                })
                npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {})
            else
                minetest.log("Walking randomly")
                -- Walk in a random direction
                local npc_pos = self.object:getpos()
                npc.exec.proc.enqueue(self, npc.programs.instr.default.WALK_STEP, {
                    dir = "random_orthogonal",
                    start_pos = npc_pos,
                    speed = speed
                })
                npc.exec.proc.enqueue(self, npc.programs.instr.default.STAND, {})
            end
        end
    else
        -- Object found, switch to idle
        npc.exec.set_state_program(self, "advanced_npc:idle", {acknowledge_nearby_objs = true}, {})
        return
    end

    -- Calculate idle chance
    local calculated_idle_chance = math.random(0, 100)
    if calculated_idle_chance < idle_chance then
        npc.log("INFO", "Switching BACK to idle state")
        -- Change to idle state process
        npc.exec.set_state_program(self, "advanced_npc:idle", {acknowledge_nearby_objs = acknowledge_nearby_objs}, {})
    end

end)

