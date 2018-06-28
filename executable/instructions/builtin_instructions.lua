--
-- Created by IntelliJ IDEA.
-- Date: 3/8/18
-- Time: 2:16 PM
--

---------------------------------------------------------------------------------------
-- Default advanced_npc instructions
---------------------------------------------------------------------------------------
-- Provides a rich set of default instructions to perform most common actions
-- a NPC needs to, like walking, rotating, standing, sitting, inventory
-- interaction, etc.

npc.programs.instr.default = {
    SET_INTERVAL = "advanced_npc:set_instruction_interval",
    WAIT = "advanced_npc:wait",
    SET_PROCESS_INTERVAL = "advanced_npc:set_process_interval",
    FREEZE = "advanced_npc:freeze",
    INTERRUPT = "advanced_npc:interrupt",
    DIG = "advanced_npc:dig",
    PLACE = "advanced_npc:place",
    ROTATE = "advanced_npc:rotate",
    WALK_STEP = "advanced_npc:walk_step",
    STAND = "advanced_npc:stand",
    SIT = "advanced_npc:sit",
    LAY = "advanced_npc:lay",
    PUT_ITEM = "advanced_npc:external_inventory_put",
    TAKE_ITEM = "advanced_npc:external_inventory_take",
    CHECK_ITEM = "advanced_npc:external_inventory_check",
    USE_OPENABLE = "advanced_npc:use_openable_node"
}

-- Control instructions --
-- The following instruction alters the instruction timer interval, therefore
-- making waits and pauses possible, or increase timing when some commands want to
-- be performed faster, like walking.
npc.programs.instr.register("advanced_npc:set_instruction_interval", function(self, args)
    local new_interval = args.interval
    local freeze_mobs_api = args.freeze

    self.execution.process_queue[1].execution_context.instr_interval = new_interval
    return not freeze_mobs_api
end)

npc.programs.instr.register("advanced_npc:set_process_interval", function(self, args)
    local new_interval = args.interval
    -- Update interval
    self.execution.scheduler_interval = new_interval
end)

-- Syntacic sugar to make a process wait for a specific interval
npc.programs.instr.register("advanced_npc:wait", function(self, args)
    local wait_time = args.time
    -- npc.programs.instr.execute(self, "advanced_npc:set_process_interval", {interval = wait_time - 1})
    -- npc.exec.proc.enqueue(self, "advanced_npc:set_process_interval", {interval = 1})
    npc.programs.instr.execute(self, "advanced_npc:set_instruction_interval", {interval = wait_time - 1})
    npc.exec.proc.enqueue(self, "advanced_npc:set_instruction_interval", {interval = 1})
end)

-- The following command is for allowing the rest of mobs redo API to be executed
-- after this command ends. This is useful for times when no command is needed
-- and the NPC is allowed to roam freely.
npc.programs.instr.register("advanced_npc:freeze", function(self, args)
    local freeze_mobs_api = args.freeze
    local disable_rightclick = args.disable_rightclick
    if disable_rightclick ~= nil then
        npc.log("INFO", "Enabling right-click interrupts for NPC "..self.npc_name..": "..dump(not(disable_rightclick)))
        self.enable_rightclick_interaction = not(disable_rightclick)
    end

    return not(freeze_mobs_api)
end)

-- This instruction allow interrupts to be enqueable, in case some programs
-- needs to be run in the future.
npc.programs.instr.register("advanced_npc:interrupt", function(self, args)
    local new_program = args.new_program
    local new_args = args.new_args
    local interrupt_options = args.interrupt_options

    npc.exec.interrupt(self, new_program, new_args, interrupt_options)
end)

npc.programs.instr.register("advanced_npc:set_interrupt_options", function(self, args)
    local allow_punch = args.allow_punch
    local allow_rightclick = args.allow_rightclick
    local allow_schedule = args.allow_schedule
    -- Set defaults
    if allow_punch == nil then allow_punch = true end
    if allow_rightclick == nil then allow_rightclick = true end
    if allow_schedule == nil then allow_schedule = true end

    -- Set interrupt options
    self.execution.process_queue[1].interrupt_options = {
        allow_punch = allow_punch,
        allow_rightclick = allow_rightclick,
        allow_schedule = allow_schedule
    }
    npc.log("INFO", "New process: "..dump(self.execution.process_queue[1]))
end)

-- This instructions sets the object animation
npc.programs.instr.register("advanced_npc:set_animation", function(self, args)
    self.object:set_animation(
        {
            x = args.start_frame, 
            y = args.end_frame
        },
        args.frame_speed, 
        args.frame_blend or 0,
        args.frame_loop or true)
end)


-- Interaction instructions --
-- This command digs the node at the given position
-- If 'add_to_inventory' is true, it will put the digged node in the NPC
-- inventory.
-- Returns true if dig is successful, otherwise false
npc.programs.instr.register("advanced_npc:dig", function(self, args)
    local pos = args.pos
    local add_to_inventory = args.add_to_inventory
    local bypass_protection = args.bypass_protection
    local play_sound = args.play_sound or true
    local node = minetest.get_node_or_nil(pos)
    if node then
        -- Set mine animation
        self.object:set_animation({
            x = npc.ANIMATION_MINE_START,
            y = npc.ANIMATION_MINE_END},
            self.animation.speed_normal, 0)

        -- Play dig sound
        if play_sound == true then
            if minetest.registered_nodes[node.name].sounds then
                minetest.sound_play(
                    minetest.registered_nodes[node.name].sounds.dug,
                    {
                        max_hear_distance = 10,
                        object = self.object
                    }
                )
            end
        end

        -- Check if protection not enforced
        if not bypass_protection then
            -- Try to dig node
            if minetest.dig_node(pos) then
                -- Add to inventory the node drops
                if add_to_inventory then
                    -- Get node drop
                    local drop = minetest.registered_nodes[node.name].drop
                    local drop_itemname = node.name
                    if drop and drop.items then
                        local random_item = drop.items[math.random(1, #drop.items)]
                        if random_item then
                            drop_itemname = random_item.items[1]
                        end
                    end
                    -- Add to NPC inventory
                    npc.add_item_to_inventory(self, drop_itemname, 1)
                end
                --return true
                return
            end
        else
            -- Add to inventory
            if add_to_inventory then
                -- Get node drop
                local drop = minetest.registered_nodes[node.name].drop
                local drop_itemname = node.name
                if drop and drop.items then
                    local random_item = drop.items[math.random(1, #drop.items)]
                    if random_item then
                        drop_itemname = random_item.items[1]
                    end
                end
                -- Add to NPC inventory
                npc.add_item_to_inventory(self, drop_itemname, 1)
            end
            -- Dig node
            minetest.log("Setting air at pos: "..minetest.pos_to_string(pos))
            minetest.set_node(pos, {name="air"})
        end
    end
    --return false
end)

-- This command places a given node at the given position
-- There are three ways to source the node:
--   1. take_from_inventory: takes node from inventory. If not in inventory,
--		node isn't placed.
--	 2. take_from_inventory_forced: takes node from inventory. If not in
--		inventory, node will be placed anyways.
--   3. force_place: places node regardless of inventory - will not touch
--		the NPCs inventory
npc.programs.instr.register("advanced_npc:place", function(self, args)
    local pos = args.pos
    local node = args.node
    local source = args.source
    local bypass_protection = args.bypass_protection
    local play_sound = args.play_sound or true
    local node_at_pos = minetest.get_node_or_nil(pos)
    -- Check if position is empty or has a node that can be built to
    if node_at_pos and
            (node_at_pos.name == "air" or minetest.registered_nodes[node_at_pos.name].buildable_to == true) then
        -- Check protection
        if (not bypass_protection and not minetest.is_protected(pos, self.npc_name))
                or bypass_protection == true then
            -- Take from inventory if necessary
            local place_item = false
            if source == npc.programs.const.place_src.take_from_inventory then
                if npc.take_item_from_inventory(self, node, 1) then
                    place_item = true
                end
            elseif source == npc.programs.const.place_src.take_from_inventory_forced then
                npc.take_item_from_inventory(self, node, 1)
                place_item = true
            elseif source == npc.programs.const.place_src.force_place then
                place_item = true
            end
            -- Place node
            if place_item == true then
                -- Set mine animation
                self.object:set_animation({
                    x = npc.ANIMATION_MINE_START,
                    y = npc.ANIMATION_MINE_END},
                    self.animation.speed_normal, 0)
                -- Place node
                minetest.set_node(pos, {name=node})
                -- Play place sound
                if play_sound == true then
                    if minetest.registered_nodes[node].sounds then
                        minetest.sound_play(
                            minetest.registered_nodes[node].sounds.place,
                            {
                                max_hear_distance = 10,
                                object = self.object
                            }
                        )
                    end
                end
            end
        end
    end
end)

-- The following instruction simulates what a player does when it punches something.
-- In this case, we have two possibilities:
--   - Punch an object (entity or player),
--   - Punch a node
-- If directed against a node, and the node has no special on_punch() callback,
-- the `advanced_npc:dig` instruction will be executed
-- Arguments:
--   - `pointed_thing`, for consistency, this is as explained in the `lua_api.txt`,
--     but without the `{type="nothing"} support. It supports the other two definitions.
--   - `wield_item`, which is an itemstring, that represents the item the NPC
--     is wielding at the time of punching.
npc.programs.instr.register("advanced_npc:punch", function(self, args)
    local pointed_thing = self.pointed_thing
    local target_type = pointed_thing.type
    local target_pos = pointed_thing.above
    local target_obj = pointed_thing.ref
    local wielded_item = args.wielded_item
    local time_from_last_punch = minetest.get_gametime() - self.npc_state.punch.last_punch_time

    -- Set time from last punch
    self.npc_state.punch.last_punch_time = minetest.get_gametime()

    -- If given, enable wielded item
    if wielded_item then
        self:set_wielded_item(wielded_item)
    end

    if target_type == "object" and target_obj then
        -- Call obj's punch()
        target_obj:punch(self, time_from_last_punch, self.object:getyaw())
    elseif target_type == "node" and target_pos then
        local node = minetest.get_node(target_pos)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and node_def.on_punch then
            -- Call the node's on_punch
            node_def.on_punch(target_pos, node, self, {type="node", above=target_pos, below=target_pos})
        else
            -- Execute the dig instrcution
            npc.programs.instr.execute(self, npc.programs.instr.default.DIG, {
                pos = target_pos,
                bypass_protection = false,
                add_to_inventory = true
            })
        end
    end
end)

-- The following instruction simulates what a player does when it rightclicks something.
-- In this case, we have two possibilities:
--   - Right-click an object (entity or player),
--   - Right-click a node
-- Arguments:
--   - `pointed_thing`, for consistency, this is as explained in the `lua_api.txt`,
--     but without the `{type="nothing"} support. It supports the other two definitions.
--   - `wield_item`, which is an itemstring, that represents the item the NPC
--     is wielding at the time of punching.
npc.programs.instr.register("advanced_npc:rightclick", function(self, args)
    local pointed_thing = self.pointed_thing
    local target_type = pointed_thing.type
    local target_pos = pointed_thing.above
    local target_obj = pointed_thing.ref
    local wielded_item = args.wielded_item

    -- If given, enable wielded item
    if wielded_item then
        self:set_wielded_item(wielded_item)
    end

    if target_type == "object" and target_obj then
        -- Call obj's right-click()
        target_obj:right_click(self)
    elseif target_type == "node" and target_pos then
        local node = minetest.get_node(target_pos)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and node_def.on_rightclick then
            -- Call the node's on_punch
            node_def.on_rightclick(target_pos, node, self, self.object:get_wielded_item(), pointed_thing)
        end
    end
end)

-- This instruction allows the NPC to craft a certain item if it has
-- the required items on its inventory. If the "force_craft" option is
-- used, the NPC will get the item regardless if it has the required items
-- or not
npc.programs.instr.register("advanced_npc:craft", function(self, args)
    local item = args.item
    local source = args.source

    -- Check if source is force-craft, if it is, just add the item to inventory
    if source == npc.programs.const.craft_src.force_craft then
        -- Add item to inventory
        npc.add_item_to_inventory_itemstring(self, item)
        return
    end

    local recipes = minetest.get_all_craftt_recipes(item)
    -- Iterate through recipes, only care about those that are "normal",
    -- we don't care about cooking or fuel recipes.
    -- Check if required items are present
    if recipes then
        for i = 1, #recipes do
            if recipe.method == "normal" then
                local missing_items = {}
                if recipe.items then
                    -- Check how many items we have and which we don't
                    for i = 1, #recipe.items do
                        if npc.inventory_contains(self, recipe.items[i]) == nil then
                            missing_items[#missing_items + 1] = recipe.items[i]
                        end
                    end
                    -- Now, check the source for items
                    local craftable = false
                    if source == npc.programs.const.craft_src.take_from_inventory then
                        -- Check if we have all
                        if next(missing_items) == nil then
                            craftable = true
                        end
                    elseif source == npc.programs.const.craft_src.take_from_inventory_forced then
                        -- Check if we have missing items
                        if next(missing_items) ~= nil then
                            -- Add all missing items
                            for j = 1, #missing_items do
                                npc.add_item_to_inventory(self, missing_items[j], 1)
                            end
                            craftable = true
                        end
                    end
                    -- Check if item is craftable
                    if craftable == true then
                        -- We have all items, craft
                        -- First, remove all items from NPC inventory
                        for j = 1, #recipe.items do
                            npc.take_item_from_inventory(self, recipe.items[j], 1)
                        end
                        -- Then add "crafted" element
                        npc.add_item_to_inventory_itemstring(self, item)
                        return true
                    end
                    return false
                end
            end
        end
    else
        npc.log("WARNING", "[instr][craft] Found no recipes for item: "..dump(args.item))
    end
end)

-- This command is to rotate a mob to a specifc direction. Currently, the code
-- contains also for diagonals, but remaining in the orthogonal domain is preferrable.
npc.programs.instr.register("advanced_npc:rotate", function(self, args)
    local dir = args.dir
    local yaw = args.yaw or 0
    local start_pos = args.start_pos
    local end_pos = args.end_pos
    -- Calculate dir if positions are given
    if start_pos and end_pos and not dir then
        dir = npc.programs.helper.get_direction(start_pos, end_pos)
    end
    -- Only yaw was given
    if yaw and not dir and not start_pos and not end_pos then
        if (yaw ~= yaw) then yaw = 0 end
        --if type(yaw) == "table" then yaw = 0 end
        self.object:setyaw(yaw)
        return
    end

    self.rotate = 0
    if dir == npc.direction.north then
        yaw = 0
    elseif dir == npc.direction.north_east then
        yaw = (7 * math.pi) / 4
    elseif dir == npc.direction.east then
        yaw = (3 * math.pi) / 2
    elseif dir == npc.direction.south_east then
        yaw = (5 * math.pi) / 4
    elseif dir == npc.direction.south then
        yaw = math.pi
    elseif dir == npc.direction.south_west then
        yaw = (3 * math.pi) / 4
    elseif dir == npc.direction.west then
        yaw = math.pi / 2
    elseif dir == npc.direction.north_west then
        yaw = math.pi / 4
    end
    if (yaw ~= yaw) then yaw = 0 end
    self.object:setyaw(yaw)
end)

-- This function will make the NPC walk one step on a
-- specifc direction. One step means one node. It returns
-- true if it can move on that direction, and false if there is an obstacle
npc.programs.instr.register("advanced_npc:walk_step", function(self, args)
    local dir = args.dir
    local yaw = args.yaw or 0
    local step_into_air_only = args.step_into_air_only
    local speed = args.speed
    local target_pos = args.target_pos
    local start_pos = args.start_pos
    local vel = {}

    -- Set default node per seconds
    if speed == nil then
        speed = npc.programs.const.speeds.one_nps_speed
    end

    -- Only yaw was given, purely rotate and walk in that dir
    if yaw and not dir then
        vel = vector.multiply(vector.normalize(minetest.yaw_to_dir(yaw)), speed)
    else
        -- Check if dir should be random
        if dir == "random_all" or dir == "random" then
            dir = npc.programs.helper.random_dir(start_pos, speed, 0, 7)
        end
        if dir == "random_orthogonal" then
            dir = npc.programs.helper.random_dir(start_pos, speed, 0, 3)
            --minetest.log("Returned: "..dump(dir))
        end
        
        if dir == npc.direction.north then
            vel = {x=0, y=0, z=speed}
        elseif dir == npc.direction.north_east then
            vel = {x=speed, y=0, z=speed}
        elseif dir == npc.direction.east then
            vel = {x=speed, y=0, z=0}
        elseif dir == npc.direction.south_east then
            vel = {x=speed, y=0, z=-speed}
        elseif dir == npc.direction.south then
            vel = {x=0, y=0, z=-speed}
        elseif dir == npc.direction.south_west then
            vel = {x=-speed, y=0, z=-speed}
        elseif dir == npc.direction.west then
            vel = {x=-speed, y=0, z=0}
        elseif dir == npc.direction.north_west then
            vel = {x=-speed, y=0, z=speed }
        else
            -- No direction provided or NPC is trapped, center NPC position
            -- and return
            -- local npc_pos = self.object:getpos()
            -- local proper_pos = {x=math.floor(npc_pos.x), y=npc_pos.y, z=math.floor(npc_pos.z)}
            -- self.object:moveto(proper_pos)
            return
        end
    end

    -- If there is a target position to reach, set it and set walking to true
    if target_pos ~= nil then
        self.npc_state.movement.walking.target_pos = target_pos
        -- Set is_walking = true
        npc.set_movement_state(self, {is_walking = true})
    end

    -- Rotate NPC
    npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE, {dir=dir, yaw=yaw})
    -- Set velocity so that NPC walks
    self.object:setvelocity(vel)
    -- Set walk animation
    self.object:set_animation({
        x = npc.ANIMATION_WALK_START,
        y = npc.ANIMATION_WALK_END},
        self.animation.speed_normal, 0)
end)

-- This command makes the NPC stand and remain like that
npc.programs.instr.register("advanced_npc:stand", function(self, args)
    local pos = args.pos
    local dir = args.dir
    local yaw = args.yaw
    -- Set is_walking = false
    npc.set_movement_state(self, {is_idle = true})
    -- Stop NPC
    self.object:setvelocity({x=0, y=0, z=0})
    -- If position given, set to that position
    if pos ~= nil then
        self.object:moveto(pos)
    end
    -- If dir given, set to that dir
    if dir ~= nil or yaw ~= nil then
        npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE, {dir=dir, yaw=yaw})
    end
    -- Set stand animation
    self.object:set_animation({
        x = npc.ANIMATION_STAND_START,
        y = npc.ANIMATION_STAND_END},
        self.animation.speed_normal, 0)
end)

-- This command makes the NPC sit on the node where it is
npc.programs.instr.register("advanced_npc:sit", function(self, args)
    local pos = args.pos
    local dir = args.dir
    -- Set movement state
    npc.set_movement_state(self, {is_idle = true, is_sitting = true})
    -- Stop NPC
    self.object:setvelocity({x=0, y=0, z=0})
    -- If position given, set to that position
    if pos ~= nil then
        self.object:moveto(pos)
    end
    -- If dir given, set to that dir
    if dir ~= nil then
        npc.programs.instr.execute(self, npc.programs.instr.default.ROTATE, {dir=dir})
    end
    -- Set sit animation
    self.object:set_animation({
        x = npc.ANIMATION_SIT_START,
        y = npc.ANIMATION_SIT_END},
        self.animation.speed_normal, 0)
end)

-- This command makes the NPC lay on the node where it is
npc.programs.instr.register("advanced_npc:lay", function(self, args)
    local pos = args.pos
    -- Set movement state
    npc.set_movement_state(self, {is_idle = true, is_laying = true})
    -- Stop NPC
    self.object:setvelocity({x=0, y=0, z=0})
    -- If position give, set to that position
    if pos ~= nil then
        self.object:moveto(pos)
    end
    -- Set sit animation
    self.object:set_animation({
        x = npc.ANIMATION_LAY_START,
        y = npc.ANIMATION_LAY_END},
        self.animation.speed_normal, 0)
end)

-- Inventory interaction instructions --
-- This function is a convenience function to make it easy to put
-- and get items from another inventory (be it a player inv or
-- a node inv)
npc.programs.instr.register("advanced_npc:external_inventory_put", function(self, args)
    local player = args.player
    local pos = args.pos
    local inv_list = args.inv_list
    local item_name = args.item_name
    local count = args.count
    local is_furnace = args.is_furnace
    local inv
    if player ~= nil then
        inv = minetest.get_inventory({type="player", name=player})
    else
        inv = minetest.get_inventory({type="node", pos=pos})
    end

    -- Create ItemStack to put on external inventory
    local item = ItemStack(item_name.." "..count)
    -- Check if there is enough room to add the item on external invenotry
    if inv:room_for_item(inv_list, item) then
        -- Take item from NPC's inventory
        if npc.take_item_from_inventory_itemstring(self, item) then
            -- NPC doesn't have item and/or specified quantity
            return false
        end
        -- Add items to external inventory
        inv:add_item(inv_list, item)

        -- If this is a furnace, start furnace timer
        if is_furnace == true then
            minetest.get_node_timer(pos):start(1.0)
        end

        return true
    end
    -- Not able to put on external inventory
    return false
end)

npc.programs.instr.register("advanced_npc:external_inventory_take", function(self, args)
    local player = args.player
    local pos = args.pos
    local inv_list = args.inv_list
    local item_name = args.item_name
    local count = args.count
    local inv
    if player ~= nil then
        inv = minetest.get_inventory({type="player", name=player})
    else
        inv = minetest.get_inventory({type="node", pos=pos})
    end
    -- Create ItemStack to take from external inventory
    local item = ItemStack(item_name.." "..count)
    -- Check if there is enough of the item to take
    if inv:contains_item(inv_list, item) then
        -- Add item to NPC's inventory
        npc.add_item_to_inventory_itemstring(self, item)
        -- Add items to external inventory
        inv:remove_item(inv_list, item)
        return true
    end
    -- Not able to put on external inventory
    return false
end)

npc.programs.instr.register("advanced_npc:external_inventory_contains", function(self, args)
    local player = args.player
    local pos = args.pos
    local inv_list = args.inv_list
    local item_name = args.item_name
    local count = args.count
    local inv
    if player ~= nil then
        inv = minetest.get_inventory({type="player", name=player})
    else
        inv = minetest.get_inventory({type="node", pos=pos})
    end

    -- Create ItemStack for checking the external inventory
    local item = ItemStack(item_name.." "..count)
    -- Check if inventory contains item
    return inv:contains_item(inv_list, item)
end)

-- This function is used to open or close openable nodes.
-- Currently supported openable nodes are: any doors using the
-- default doors API, and the cottages mod gates and doors.
npc.programs.instr.register("advanced_npc:use_openable_node", function(self, args)
    local pos = args.pos
    local command = args.command
    local dir = args.dir
    local node = minetest.get_node(pos)
    local state = npc.programs.helper.get_openable_node_state(node, pos, dir)

    -- Emulate the NPC being a player
    local clicker = self
    clicker.is_player = function() return true end
    clicker.get_player_name = function(self) return self.npc_id end
    if command ~= state then
        minetest.registered_nodes[node.name].on_rightclick(pos, node, clicker, nil, nil)
    end
end)

-- Internal NPC properties
-- These instructions are mostly syntactic sugar for doing certain operations.
npc.programs.instr.register("advanced_npc:trade:change_trader_status", function(self, args)
    -- Get status from args
    local status = args.status
    -- Set status to NPC
    npc.set_trading_status(self, status)
end)

npc.programs.instr.register("advanced_npc:trade:set_trade_list", function(self, args)
    -- Insert items
    for i = 1, #args.items do
        -- Insert entry into trade list
        self.trader_data.trade_list[args.items[i].name] = {
            max_item_buy_count = args.items[i].buy,
            max_item_sell_count = args.items[i].sell,
            amount_to_keep = args.items[i].keep
        }
    end
end)

-- Accepts itemstring
npc.programs.instr.register("advanced_npc:inventory_put", function(self, args)
    local itemstring = args.itemstring
    -- Add item
    npc.add_item_to_inventory_itemstring(self, itemstring)
end)

npc.programs.instr.register("advanced_npc:inventory_put_multiple", function(self, args)
    local itemlist = args.itemlist
    for i = 1, #itemlist do
        local itemlist_entry = itemlist[i]
        local current_itemstring = itemlist[i].name
        if itemlist_entry.random == true then
            current_itemstring = current_itemstring
                    .." "..dump(math.random(itemlist_entry.min, itemlist_entry.max))
        else
            current_itemstring = current_itemstring.." "..tostring(itemlist_entry.count)
        end
        -- Add item to inventory
        npc.add_item_to_inventory_itemstring(self, current_itemstring)
    end
end)

npc.programs.instr.register("advanced_npc:inventory_take", function(self, args)
    local itemstring = args.itemstring
    -- Add item
    npc.take_item_from_inventory_itemstring(self, itemstring)
end)
