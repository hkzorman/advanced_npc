--
-- Created by IntelliJ IDEA.
-- Date: 3/8/18
-- Time: 2:42 PM
--

-- Follow program. This is a looping program that will try to follow an
-- entity or player until either of the following conditions are met:
--   - A certain flag is set to false
--   - The object is reached and a callback executed.
-- Arguments:
--   - `radius`: integer, initial search radius. Default is 3
--   - `max_radius`: integer, maximum search radius. If target isn't found within initial radius,
--      radius will increase up to this value. Default is 20
--   - `speed`: number, walking speed for the NPC while following. Default is 3
--   - `target`: string, can be "player" or "entity".
--   - `player_name`: string, name of player to follow
--   - `entity_type`: string, type of entity to follow. NOT IMPLEMENTED.
--   - `on_reach`: function, if given, on reaching the target, this function will
--      be called and executed. On execution, the script will finish. DO NOT use with
--      `follow_flag`.
--   - `follow_flag`: string, flag name. If given, the script will keep running until the
--      value of this flag is false. DO NOT use with `on_reach`.
npc.programs.register("advanced_npc:follow", function(self, args)
    -- Set default arguments if not present
    args.radius = args.radius or 3
    args.max_radius = args.max_radius or 20
    args.speed = args.speed or 3
    args.results_key = "advanced_npc:follow:player_follow"

    -- Run this 1/speed times in a second
    npc.programs.instr.execute(self, npc.programs.instr.default.SET_INTERVAL, {interval=1/args.speed, freeze=true})
    -- Make NPC climb one-block heights. Makes following easier
    self.stepheight = 1.1
    self.object:set_properties(self)

    -- Execution
    -- Follow, results to be stored on execution context with key "results_key"
    npc.exec.proc.enqueue(self, "advanced_npc:follow:follow_player", args, args.results_key)
    -- Check if follow is complete
    npc.exec.proc.enqueue(self, "advanced_npc:follow:check_if_complete", args)
end)

-- Follow script functions
-- Function used to reset NPC values once following is complete
npc.programs.instr.register("advanced_npc:follow:reset", function(self)
    self.stepheight = 0.6
    self.object:set_properties(self)
    npc.programs.instr.execute(self, npc.programs.instr.default.SET_INTERVAL, {interval=1, freeze=false})
end)

-- Follow the player
npc.programs.instr.register("advanced_npc:follow:follow_player", function(self, args)
    if args.target == "player" then
        local player_name = args.player_name
        local objs = minetest.get_objects_inside_radius(self.object:getpos(), args.radius)
        -- Check if objects were found
        minetest.log("Objects found: "..dump(objs))
        if #objs > 0 then
            for _,obj in pairs(objs) do
                if obj then
                    -- Check if this is the player we are looking for
                    if obj:is_player() and obj:get_player_name() == player_name then
                        local target_pos = vector.round(obj:getpos())
                        -- Calculate distance - if less than 3, avoid walking any further
                        if vector.distance(self.object:getpos(), target_pos) < 3 then
                            npc.log("PROCESS", "[follow] Destination reached")
                            -- Destination reached
                            -- Add standing action if NPC is still moving
                            if math.abs(vector.length(self.object:getvelocity())) > 0 then
                                npc.programs.instr.execute(self, npc.programs.instr.default.STAND,
                                    {dir = minetest.dir_to_yaw(vector.direction(self.object:getpos(), target_pos))}
                                )
                            end

                            -- Rotate NPC towards player
                            npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE,
                                {yaw = minetest.dir_to_yaw(vector.direction(self.object:getpos(), target_pos))})

                            -- Execute `on_reach` function if present
                            if args.on_reach then
                                npc.log("PROCESS", "[follow] Executing on_reach callback...")
                                args.on_reach(self, obj)
                                return {reached_target = true, target_pos = target_pos, end_execution = true}
                            end

                            return {reached_target = true, target_pos = target_pos}
                        else
                            npc.log("PROCESS", "[follow] Walking towards player...")
                            local walk_args = {
                                yaw = minetest.dir_to_yaw(vector.direction(self.object:getpos(), target_pos)),
                                speed = args.speed
                            }
                            -- Enqueue walk step
                            npc.programs.instr.execute(self, npc.programs.instr.default.WALK_STEP, walk_args)
                            return {reached_target = false, target_pos = target_pos}
                        end
                    end
                end
            end
            -- Player not found, stop
            npc.programs.instr.execute(self, npc.programs.instr.default.STAND, {})
            return {reached_target = false, target_pos = nil}
        end
    end
    return {reached_target = false, target_pos = nil}
end)


npc.programs.instr.register("advanced_npc:follow:check_if_complete", function(self, args)
    -- Check if follow is still needed
    if npc.get_flag(self, args.follow_flag) == false then
        -- Stop, follow no more
        npc.programs.instr.execute(self, npc.programs.instr.default.STAND, {})
        -- Clear flag
        npc.update_flag(self, args.follow_flag, nil)
        -- Reset actions interval and NPC stepheight
        npc.programs.instr.execute(self, "advanced_npc:follow:reset", {})
        return
    end

    -- Get results from following
    local follow_result = npc.exec.var.get(self, args.results_key)
    -- Check results
    if follow_result == nil then
        npc.log("WARNING", "Unable to find result in execution context for 'follow_player' function using key: "..
                dump(args.results_key))
        return
    end
    -- Clean execution context
    npc.exec.var.remove(self, args.results_key)

    -- Check if target reached and on_reach function executed
    if follow_result.reached_target == true and follow_result.end_execution == true then
        return
    end
    -- on_reach is not set, keep executing until follow flag is off.
    if follow_result.target_pos ~= nil then
        -- Keep walking or waiting for player to keep moving
        npc.exec.proc.enqueue(self, "advanced_npc:follow:follow_player", args, args.results_key)
        -- Check if follow is complete
        npc.exec.proc.enqueue(self, "advanced_npc:follow:check_if_complete", args)
        --npc.enqueue_function(self, detect_more_movement, {player_pos = follow_result.target_pos})
    else
        -- Cannot find
        npc.log("PROCESS", "[follow] Walking towards player")
        -- Modify args to increase radius
        args.radius = args.radius + 1
        npc.exec.proc.enqueue(self, "advanced_npc:follow:follow_player", args, args.results_key)
        -- Check if follow is complete
        npc.exec.proc.enqueue(self, "advanced_npc:follow:check_if_complete", args)
    end
end)

