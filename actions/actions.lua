-- Commands API code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Commands API functionality
---------------------------------------------------------------------------------------
--
-- Description:
------------------------------------------------------------------------------------------
-- The Commands API is a Bash Script-like execution environment for Minetest entities.
-- There are the following fundamental constructs:
--   - commands: execute a specific action (e.g. dig a node, search for nodes, etc.)
--   - variables: stores information temporarily (e.g. results of node search)
--   - control statements: if/else and loops
--
-- All of these is done using the Lua programming language, and a few custom
-- expressions where Lua can't help.
--
-- The fundamental concept is to use the three constructs together in the form of
-- a script to allow NPCs (and any Minetest entity) to perform complex actions,
-- like walking from one place to the other, operating furnaces, etc. In this sense,
-- this "commands" API can be considered a domain-specific language (DSL), that is
-- defined using Lua language structures.
--
-- Basic definitions:
------------------------------------------------------------------------------------------
-- A `variable` is any value that can be accessed using a specific key, or name.
-- In the context of the commands API, there is an `execution` context where
-- variables can be stored into, read and deleted from. The execution context
-- is nothing but a map of key-value pairs, with the key being the variable name.
-- Some rules regarding variables:
--   - A variable can be read-write or read-only. Read-only variables cannot be
--     updated, but can be deleted.
--   - A variable cannot be overwritten by another variable of the same name.
--   - The scope of variables is global *within* a script. The execution context
--     is cleared after a script finishes executing. For more info about scripts,
--     see below.
--   - The Lua entity variables, referring to any `self.*` value isn't available
--     as a variable. This is to keep the NPC integrity from a security perspective.
--     However, as some values are very useful and often needed (such as
--     `self.object:getpos()`), some variables are exposed. These are referred to
--     as *internal* variables. They are read-only.
--
-- A 'command' is a Lua function, with only two parameters: `self`, the Lua entity,
-- and `args`, a Lua table containing all arguments required for the command. The
-- control statements (if/else, loop) and variable set/read are defined as commands
-- as well. The arguments are not strictly controlled, with the following exceptions:
--   - A `variable expression string` is special string that allows a variable
--     to be passed as an argument to a command. The reason why a function can't
--     be used for this is because the execution context, where variables are
--     stored, lives in the entity itself (the `self` object), to which there's no
--     access when a script is defined as a Lua array.
--     The special string has a specific format: "<var_type>:<var_key>" where the
--     accepted values for `<var_type>` are:
--       - `var`, referring to a variable from the execution context, and,
--       - `ivar`, referring to an internal variable (an exposed self.* variable)
--   - A `function expression table` is a Lua table that contains a executable
--     Lua function and the arguments to be executed. The function is executed
--     at the proper moment when passed as an argument to a command, instead of
--     executing immediately while defining a script.
--     The function expression table has the following format:
--     {
--        func: <Lua function>,
--        args: <Lua table of arguments for the function>
--     }
--   - A `boolean expression table` is a Lua table that is reconstructed into a
--     Lua boolean expression. The reason for this to exist is similar to the
--     above explanation, and is that, at the moment a script is defined as a
--     Lua array, any function or variable passed as a boolean expression will
--     evaluate, making the value effectively a constant. That would render
--     loops and if/else statements useless.
--     The boolean expression table has the following format:
--     {
--        left_side: <any_value|function expression table|variable expression string>,
--        operator: <string>,
--        right_side: <any value|function expression table|variable expression string>,
--     }
--   `operator` and `right_side` are optional: a single function in `left_side` is
--   enough as long as it evaluates to a `boolean` value. The `operator` argument
--   accepts the following values:
--     - `equals`
--     - `not_equals`
--     - `greater_than`
--     - `greater_than_equals`
--     - `less_than`
--     - `less_than_equals`
--   `right_side` is required if `operator` is defined.
--
-- A `script` is an ordered sequence of commands to be executed, and is defined
-- using a Lua array, where each element is a Lua function corresponding to a
-- command. Scripts are intended to be implemented by users of the API, and as
-- such it is possible to register a script for other mods to use. For example,
-- a script can be used by a mod that creates a music player node so that NPCs
-- can also be able to use it.
-- Scripts can also be executed at certain times during a Minetest day thanks
-- to the schedules functionality.
--
-- Execution:
------------------------------------------------------------------------------------------
-- The execution of commands is performed on a timer basis, per NPC, with a default
-- interval value of one second. This interval can be changed by a command itself,
-- however it is the recommended interval is one second to avoid lag caused by many NPCs
-- executing commands.
-- Commands has to be enqueued in order to execute. Enqueuing commands directly isn't
-- recommended, and instead it should be done through a script. Nonetheless, the API
-- for enqueuing commands and scripts is the following:
--   - npc.enqueue_command(command_name, args)
--   - npc.enqueue_script(script_name, args)
--
-- The control statement commands (if/else, loops) and variable set/read commands
-- will execute the next command in queue immediately after finishing instead of
-- waiting for the timer interval.
--
-- There is an `execution context` which contains all the variables that are defined
-- using the variable set commands. Also, it contains values specific to the loops,
-- like the number of times it has executed. The execution context lives in the NPC
-- `self` object, and therefore, has to be carefully used, or otherwise it can create
-- huge memory usage. In order to avoid this, variables can be deleted from the execution
-- context using a specific command (`npc.commands.del_var(key)`). Also, as basic
-- memory management routine, the `execution context` is cleared after the end of
-- executing a script.
-- To keep global variables, use the npc.command.get/set_flag() API which is not
-- deleted after execution.
------------------------------------------------------------------------------------------

npc.commands = {}
--local registered_commands = {}

npc.commands.default_interval = 1

npc.commands.dir_data = {
    -- North
    [0] = {
        yaw = 0,
        vel = {x=0, y=0, z=1}
    },
    -- East
    [1] = {
        yaw = (3 * math.pi) / 2,
        vel = {x=1, y=0, z=0}
    },
    -- South
    [2] = {
        yaw = math.pi,
        vel = {x=0, y=0, z=-1}
    },
    -- West
    [3] = {
        yaw = math.pi / 2,
        vel = {x=-1, y=0, z=0}
    },
    -- North east
    [4] = {
        yaw = (7 * math.pi) / 4,
        vel = {x=1, y=0, z=1}
    },
    -- North west
    [5] = {
        yaw = math.pi / 4,
        vel = {x=-1, y=0, z=1}
    },
    -- South east
    [6] = {
        yaw = (5 * math.pi) / 4,
        vel = {x=1, y=0, z=-1}
    },
    -- South west
    [7] = {
        yaw = (3 * math.pi) / 4,
        vel = {x=-1, y=0, z=-1}
    }
}

-- Describes commands with doors or openable nodes
npc.commands.const = {
    doors = {
        command = {
            OPEN = 1,
            CLOSE = 2
        },
        state = {
            OPEN = 1,
            CLOSED = 2
        }
    },
    beds = {
        LAY = 1,
        GET_UP = 2
    },
    sittable = {
        SIT = 1,
        GET_UP = 2
    }
}

npc.commands.internal_values = {
    POS = "self_pos",
    -- Note: The following is by mobs_redo.
    STANDING_IN = "node_standing_in"
}

npc.commands.cmd = {
    SET_INTERVAL = 0,
    FREEZE = 1,
    ROTATE = 2,
    WALK_STEP = 3,
    STAND = 4,
    SIT = 5,
    LAY = 6,
    PUT_ITEM = 7,
    TAKE_ITEM = 8,
    CHECK_ITEM = 9,
    USE_OPENABLE = 10,
    USE_FURNACE = 11,
    USE_BED = 12,
    USE_SITTABLE = 13,
    WALK_TO_POS = 14,
    DIG = 15,
    PLACE = 16
}

--npc.commands.one_nps_speed = 0.98
--npc.commands.one_half_nps_speed = 1.40
--npc.commands.two_nps_speed = 1.90'
npc.commands.one_nps_speed = 1
npc.commands.one_half_nps_speed = 1.5
npc.commands.two_nps_speed = 2

npc.commands.take_from_inventory = "take_from_inventory"
npc.commands.take_from_inventory_forced = "take_from_inventory_forced"
npc.commands.force_place = "force_place"

--------------
-- Executor --
--------------
-- Function references aren't reliable in Minetest entities. Objects get serialized
-- and deserialized, as well as loaded and unloaded frequently which causes many
-- function references to be lost and then crashes occurs due to nil variables.
-- Using constants to refer to each method of this API and a function that
-- understands those constants and executes the proper function is the way to avoid
-- this frequent crashes.
function npc.commands.execute(self, command, args)
    if command == npc.commands.cmd.SET_INTERVAL then
        --
        return npc.commands.set_interval(self, args)
    elseif command == npc.commands.cmd.FREEZE then
        --
        return npc.commands.freeze(self, args)
    elseif command == npc.commands.cmd.ROTATE then
        --
        return npc.commands.rotate(self, args)
    elseif command == npc.commands.cmd.WALK_STEP then
        --
        return npc.commands.walk_step(self, args)
    elseif command == npc.commands.cmd.STAND then
        --
        return npc.commands.stand(self, args)
    elseif command == npc.commands.cmd.SIT then
        --
        return npc.commands.sit(self, args)
    elseif command == npc.commands.cmd.LAY then
        --
        return npc.commands.lay(self, args)
    elseif command == npc.commands.cmd.PUT_ITEM then
        --
        return npc.commands.put_item_on_external_inventory(self, args)
    elseif command == npc.commands.cmd.TAKE_ITEM then
        --
        return npc.commands.take_item_from_external_inventory(self, args)
    elseif command == npc.commands.cmd.CHECK_ITEM then
        --
        return npc.commands.check_external_inventory_contains_item(self, args)
    elseif command == npc.commands.cmd.USE_OPENABLE then
        --
        return npc.commands.use_openable(self, args)
    elseif command == npc.commands.cmd.USE_FURNACE then
        --
        return npc.commands.use_furnace(self, args)
    elseif command == npc.commands.cmd.USE_BED then
        --
        return npc.commands.use_bed(self, args)
    elseif command == npc.commands.cmd.USE_SITTABLE then
        -- Call use sittable task
        return npc.commands.use_sittable(self, args)
    elseif command == npc.commands.cmd.WALK_TO_POS then
        -- Call walk to position task
        --minetest.log("Self: "..dump(self)..", Command: "..dump(command)..", args: "..dump(args))
        return npc.commands.walk_to_pos(self, args)
    elseif command == npc.commands.cmd.DIG then
        -- Call dig node command
        return npc.commands.dig(self, args)
    elseif command == npc.commands.cmd.PLACE then
        -- Call place node command
        return npc.commands.place(self, args)
    end
end

-- TODO: Thanks to executor function, all the functions for Commands and Tasks
-- should be made into private API


---------------------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------------------
-- Expression Helper functions
-- These functions provides validation and evaluation logic for the three custom
-- arguments supported:
--  - variable expression string
--  - function expression table
--  - boolean expression table
npc.commands.expr = {}

npc.commands.expr.boolean_operators = {
    EQUALS = "equals",
    NOT_EQUALS = "not_equals",
    GREATER_THAN = "greater_than",
    GREATER_THAN_EQUALS = "greater_than_equals",
    LESS_THAN = "less_than",
    LESS_THAN_EQUALS = "less_than_equals"
}

local function get_variable_arg(arg)
    if type(arg) == "string" then
        local var_exp = string.split(arg, ":")
        if var_exp[1] == "var" or var_exp[1] == "ivar" then
            return arg, true
        end
    end
    return arg, false
end

local function evaluate_variable_arg(self, var_arg)
    local var_exp = string.split(var_arg, ":")
    if var_exp[1] == "var" then
        return npc.commands.get_var(self, {key=var_exp[2]})
    elseif var_exp[1] == "ivar" then
        return npc.commands.get_internal_var(self, {key=var_exp[2]})
    end
end

local function get_function_arg(arg)
    if type(arg) == "table" then
        -- Check if this is a function expression table. If it
        -- is and is well defined, return it.
        if arg.func and arg.args then
            return arg, true
        end
    end
    return arg, false
end

local function evaluate_function_arg(func_arg)
    return func_arg.func(unpack(func_arg.args))
end

local function get_boolean_arg(arg)
    if type(arg) == "table" then
        if (arg.left_side and not(arg.operator and arg.right_side))
                or (arg.left_side and arg.operator and arg.right_side) then
            return arg, true
        end
        return arg, false
    end
end

local function evaluate_boolean_arg(bool_arg)
    local left_side = npc.commands.expr.evaluate_argument(bool_arg.left_side)
    local right_side, operator
    if bool_arg.right_side then
        right_side = npc.commands.expr.evaluate_argument(bool_arg.right_side)
        operator = bool_arg.operator
    end
    if right_side then
        if operator == npc.commands.expr.boolean_operators.EQUALS then
            return left_side == right_side
        elseif operator == npc.commands.expr.boolean_operators.NOT_EQUALS then
            return left_side ~= right_side
        elseif operator == npc.commands.expr.boolean_operators.GREATER_THAN then
            return left_side > right_side
        elseif operator == npc.commands.expr.boolean_operators.GREATER_THAN_EQUALS then
            return left_side >= right_side
        elseif operator == npc.commands.expr.boolean_operators.LESS_THAN then
            return left_side < right_side
        elseif operator == npc.commands.expr.boolean_operators.LESS_THAN_EQUALS then
            return left_side <= right_side
        end
    else
        return left_side
    end
end

-- This function identifies the type of argument we are dealing with.
function npc.commands.expr.get_argument_type(arg)
    local _, check = get_function_arg(arg)
    if check then
        return "function_expression"
    else
        _, check = get_variable_arg(arg)
        if check then
            return "variable_expression"
        else
            _, check = get_boolean_arg(arg)
            if check then
                return "boolean_expression"
            end
        end
    end
    return type(arg)
end

function npc.commands.expr.evaluate_argument(arg)
    local argument_type = npc.commands.expr.get_argument_type(arg)
    if argument_type == "function_expression" then
        return evaluate_function_arg(arg)
    elseif argument_type == "variable_expression" then
        return evaluate_variable_arg(arg)
    elseif argument_type == "boolean_expression" then
        return evaluate_boolean_arg(arg)
    else
        return arg
    end
end

--------------------------
-- Declarative commands --
--------------------------
-- These commands declare, assign and fetch variable values

-- This command sets the value of a variable in the execution context.
-- If the variable doesn't exists, then it creates the variable and
-- sets its value.
-- Arguments:
--   - key: variable name
--   - value: variable value
-- Returns: Nothing
function npc.commands.set_var(self, args)
    if args.key then
        local result = npc.execution_context.get(self, args.key)
        if result then
            npc.execution_context.set(self, args.key, args.value)
        else
            npc.execution_context.put(self, args.key, args.value, false)
        end
    end
end

-- This command returns the value of a variable in the execution context.
-- If the variable doesn't exists, returns nil.
-- Arguments:
--   - key: variable name
-- Returns: variable value if found, nil otherwise
function npc.commands.get_var(self, args)
    if args.key then
        return npc.execution_context.get(self, args.key)
    end
end

-- This command returns the value of an internal NPC variable.
-- These variables are the self.* variables, limited for security
-- purposes. The list of retrievable values is defined in
-- npc.commands.internal_values.*
-- Arguments:
--   - key: internal value as specified in npc.commands.internal_values.*
-- Returns: internal value
function npc.commands.get_internal_var(self, args)
    local key = args.key
    if key then
        if key == npc.commands.internal_values.POS then
            return self.object:getpos()
        elseif key == npc.commands.internal_values.STANDING_IN then
            return self.standing_in
        end
    end
end

-- This command deletes a variable from the execution context.
-- If the deletion is successful, it returns the value of the deleted
-- variable. If not, it returns nil
-- Arguments:
--   - key: key-name of the variable to be deleted
function npc.commands.del_var(self, args)
    local key = args.key
    if key then
        return npc.execution_context.remove(self, key)
    end
end

-----------------------
-- Control commands --
-----------------------
-- The following command alters the timer interval for executing commands, therefore
-- making waits and pauses possible, or increase timing when some commands want to
-- be performed faster, like walking.
function npc.commands.set_interval(self, args)
    local self_actions = args.self_actions
    local new_interval = args.interval
    local freeze_mobs_api = args.freeze

    self.commands.action_interval = new_interval
    return not freeze_mobs_api
end

-- The following command is for allowing the rest of mobs redo API to be executed
-- after this command ends. This is useful for times when no command is needed
-- and the NPC is allowed to roam freely.
function npc.commands.freeze(self, args)
    local freeze_mobs_api = args.freeze
    local disable_rightclick = args.disable_rightclick
    if disable_rightclick ~= nil then
        npc.log("INFO", "Enabling interactions for NPC "..self.npc_name..": "..dump(not(disable_rightclick)))
        self.enable_rightclick_interaction = not(disable_rightclick)
    end

    return not(freeze_mobs_api)
end

-- This command allows the conditional execution of two array of commands
-- depending on the evaluation of a certain condition. This is the typical
-- if-else statement of a programming language. If-else can be nested.
-- Arguments:
--   - `condition`: accepts two values:
--     - `boolean`: Lua boolean expression, any expression that evaluates to `true` or `false`.
--     - `table`: A boolean expression table.
--   - `true_commands`: an array of commands to be executed when the condition
--     evaluates to `true`
--   - `false_commands`: an array of commands to be executed when the condition
--     evaluates to `false`
function npc.commands.if_else(self, args)

end

-- This command works as the types of loops, depending on the arguments
-- given. It can work as a while, a for and a for-each loop. Loops can
-- be nested.
-- While-loop arguments:
--   - `name`: string, a key-name for this loop. Default is nil. If given,
--     it gives access to the number of times the loop has executed.
--   - `condition`: boolean, the loop will be executed as long as this condition
--     evaluates to `true`
--   - `commands`: array, array of commands to be executed during the loop
--
-- For-loop arguments:
--   - `name`: string, a key-name for this loop. Default is `nil`. If given, it
--     gives access to the number of times this loop has executed.
--   - `initial_value`: integer, the starting value of the for-loop. If left
--     blank, default value is `1`.
--   - `condition`: boolean, the loop will be executed as long as this condition
--     evaluates to `true`.
--   - `modifier`: function, the loop will execute this modifier at the end of
--     every iteration. If left blank, default is: initial_value + 1
--   - `commands`: array, array of commands to be executed during the loop
--
-- Both of these loops store how many times they have been executed. To
-- access it, it is required to give pass the argument `name`. Then the
-- value will be stored on the execution context and the value retrievable
-- with `npc.commands.get_context(key)`, where `key` is the `name` argument.
--
-- For-each-loop arguments:
--   - `name`: string, a key-name for this loop. Default is `nil`. If given, it
--     gives access to the number of times this loop has executed and the current
--     value of the array/table being evaluated.
--   - `iterable`: array or table of key-value pairs, this is an iterable array
--     or table for which the loop will execute commands at every element in the
--     iterable array/table.
--   - `commands`: array, array of commands to be executed during the loop
-- To get the current element being iterated in a for-each loop, you need to define
-- the `name` argument. Then, the value will be stored in the execution context and
-- will be retrievable with `npc.commands.get_context(key)`. It will return a table
-- like this: {loop_count = x, current_value = y}
function npc.commands.loop(self, args)

end



--------------------------
-- Interaction commands --
--------------------------
-- This command digs the node at the given position
-- If 'add_to_inventory' is true, it will put the digged node in the NPC
-- inventory.
-- Returns true if dig is successful, otherwise false
function npc.commands.dig(self, args)
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
            minetest.sound_play(
                minetest.registered_nodes[node.name].sounds.dug,
                {
                    max_hear_distance = 10,
                    object = self.object
                }
            )
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
            minetest.set_node(pos, {name="air"})
        end
    end
    --return false
end


-- This command places a given node at the given position
-- There are three ways to source the node:
--   1. take_from_inventory: takes node from inventory. If not in inventory,
--		node isn't placed.
--	 2. take_from_inventory_forced: takes node from inventory. If not in
--		inventory, node will be placed anyways.
--   3. force_place: places node regardless of inventory - will not touch
--		the NPCs inventory
function npc.commands.place(self, args)
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
            if source == npc.commands.take_from_inventory then
                if npc.take_item_from_inventory(self, node, 1) then
                    place_item = true
                end
            elseif source == npc.commands.take_from_inventory_forced then
                npc.take_item_from_inventory(self, node, 1)
                place_item = true
            elseif source == npc.commands.force_place then
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

-- This function allows to query for nodes and entities within a radius.
-- Parameters:
--   - query_type: string, specifies whether to query nodes or entities.
--     Default value is "node". Accepted values are:
--     - "node"
--     - "entity"
--   - position: table or string, specifies the starting position
--     for query. This should be the center of a square box. If
--     given a String, the string should be the place type.
--     Two types of tables are accepted:
--       - A simple position table, {x=1, y=1, z=1}
--       - An improved position table in this format:
--         {
-- 		     place_category = "",
-- 		     place_type = "",
-- 		     index = 1, (specific index in the places map)
-- 	 	     use_access_node = false|true,
--         }
--    - radius: integer, specifies the radius of the square box to search
--      around the starting position.
--    - result_type: string, specifies how to return results. Accepted
--      values are:
--       - "first": Get the first result found (default if left blank),
--       - "nearest": Get the result nearest to the NPC,
--       - "all": Return array of all results
function npc.commands.query(self, args)

end



-- This function allows to move into directions that are walkable. It
-- avoids fences and allows to move on plants.
-- This will make for nice wanderings, making the NPC move smartly instead
-- of just getting stuck at places
local function random_dir_helper(start_pos, speed, dir_start, dir_end)
    -- Limit the number of tries - otherwise it could become an infinite loop
    for i = 1, 8 do
        local dir = math.random(dir_start, dir_end)
        local vel = vector.multiply(npc.commands.dir_data[dir].vel, speed)
        local pos = vector.add(start_pos, vel)
        local node = minetest.get_node(pos)
        if node then
            if node.name == "air"
                    -- Any walkable node except fences
                    or (minetest.registered_nodes[node.name].walkable == true
                    and minetest.registered_nodes[node.name].groups.fence ~= 1)
                    -- Farming plants
                    or minetest.registered_nodes[node.name].groups.plant == 1 then
                return dir
            end
        end
    end
    -- Return -1 signaling that no good direction could be found
    return -1
end

-- This command is to rotate to mob to a specifc direction. Currently, the code
-- contains also for diagonals, but remaining in the orthogonal domain is preferrable.
function npc.commands.rotate(self, args)
    local dir = args.dir
    local yaw = args.yaw or 0
    local start_pos = args.start_pos
    local end_pos = args.end_pos
    -- Calculate dir if positions are given
    if start_pos and end_pos and not dir then
        dir = npc.commands.get_direction(start_pos, end_pos)
    end
    -- Only yaw was given
    if yaw and not dir and not start_pos and not end_pos then
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
    self.object:setyaw(yaw)
end

-- This function will make the NPC walk one step on a
-- specifc direction. One step means one node. It returns
-- true if it can move on that direction, and false if there is an obstacle
function npc.commands.walk_step(self, args)
    local dir = args.dir
    local step_into_air_only = args.step_into_air_only
    local speed = args.speed
    local target_pos = args.target_pos
    local start_pos = args.start_pos
    local vel = {}

    -- Set default node per seconds
    if speed == nil then
        speed = npc.commands.one_nps_speed
    end

    -- Check if dir should be random
    if dir == "random_all" or dir == "random" then
        dir = random_dir_helper(start_pos, speed, 0, 7)
    end
    if dir == "random_orthogonal" then
        dir = random_dir_helper(start_pos, speed, 0, 3)
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
        -- No direction provided or NPC is trapped, don't move NPC
        vel = {x=0, y=0, z=0}
    end

    -- If there is a target position to reach, set it and set walking to true
    if target_pos ~= nil then
        self.commands.walking.target_pos = target_pos
        -- Set is_walking = true
        self.commands.walking.is_walking = true
    end

    -- Rotate NPC
    npc.commands.rotate(self, {dir=dir})
    -- Set velocity so that NPC walks
    self.object:setvelocity(vel)
    -- Set walk animation
    self.object:set_animation({
        x = npc.ANIMATION_WALK_START,
        y = npc.ANIMATION_WALK_END},
        self.animation.speed_normal, 0)
end

-- This command makes the NPC stand and remain like that
function npc.commands.stand(self, args)
    local pos = args.pos
    local dir = args.dir
    -- Set is_walking = false
    self.commands.walking.is_walking = false
    -- Stop NPC
    self.object:setvelocity({x=0, y=0, z=0})
    -- If position given, set to that position
    if pos ~= nil then
        self.object:moveto(pos)
    end
    -- If dir given, set to that dir
    if dir ~= nil then
        npc.commands.rotate(self, {dir=dir})
    end
    -- Set stand animation
    self.object:set_animation({
        x = npc.ANIMATION_STAND_START,
        y = npc.ANIMATION_STAND_END},
        self.animation.speed_normal, 0)
end

-- This command makes the NPC sit on the node where it is
function npc.commands.sit(self, args)
    local pos = args.pos
    local dir = args.dir
    -- Stop NPC
    self.object:setvelocity({x=0, y=0, z=0})
    -- If position given, set to that position
    if pos ~= nil then
        self.object:moveto(pos)
    end
    -- If dir given, set to that dir
    if dir ~= nil then
        npc.commands.rotate(self, {dir=dir})
    end
    -- Set sit animation
    self.object:set_animation({
        x = npc.ANIMATION_SIT_START,
        y = npc.ANIMATION_SIT_END},
        self.animation.speed_normal, 0)
end

-- This command makes the NPC lay on the node where it is
function npc.commands.lay(self, args)
    local pos = args.pos
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
end

-- Inventory functions for players and for nodes
-- This function is a convenience function to make it easy to put
-- and get items from another inventory (be it a player inv or
-- a node inv)
function npc.commands.put_item_on_external_inventory(self, args)
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
end

function npc.commands.take_item_from_external_inventory(self, args)
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
end

function npc.commands.check_external_inventory_contains_item(self, args)
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
end

-- TODO: Refactor this function so that it uses a table to check
-- for doors instead of having separate logic for each door type
function npc.commands.get_openable_node_state(node, pos, npc_dir)
    --minetest.log("Node name: "..dump(node.name))
    local state = npc.commands.const.doors.state.CLOSED
    -- Check for MTG doors and gates
    local mtg_door_closed = false
    if minetest.get_item_group(node.name, "door") > 0 then
        local back_pos = vector.add(pos, minetest.facedir_to_dir(node.param2))
        local back_node = minetest.get_node(back_pos)
        if back_node.name == "air" or minetest.registered_nodes[back_node.name].walkable == false then
            mtg_door_closed = true
        end
    end
    -- Check for cottages gates
    local open_i1, open_i2 = string.find(node.name, "_close")
    -- Check for cottages half door
    local half_door_is_closed = false
    if node.name == "cottages:half_door" then
        half_door_is_closed = (node.param2 + 2) % 4 == npc_dir
    end
    if mtg_door_closed == false and open_i1 == nil and half_door_is_closed == false then
        state = npc.commands.const.doors.state.OPEN
    end
    --minetest.log("Door state: "..dump(state))
    return state
end

-- This function is used to open or close openable nodes.
-- Currently supported openable nodes are: any doors using the
-- default doors API, and the cottages mod gates and doors.
function npc.commands.use_openable(self, args)
    local pos = args.pos
    local command = args.command
    local dir = args.dir
    local node = minetest.get_node(pos)
    local state = npc.commands.get_openable_node_state(node, pos, dir)

    local clicker = self.object
    if command ~= state then
        minetest.registered_nodes[node.name].on_rightclick(pos, node, clicker, nil, nil)
    end
end


---------------------------------------------------------------------------------------
-- Tasks functionality
---------------------------------------------------------------------------------------
-- Tasks are operations that require many commands to perform. Basic tasks, like
-- walking from one place to another, operating a furnace, storing or taking
-- items from a chest, are provided here.

local function get_pos_argument(self, pos, use_access_node)
    --minetest.log("Type of pos: "..dump(type(pos)))
    -- Check which type of position argument we received
    if type(pos) == "table" then
        --minetest.log("Received table pos: "..dump(pos))
        -- Check if table is position
        if pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
            -- Position received, return position
            return pos
        elseif pos.place_type ~= nil then
            -- Received table in the following format:
            -- {
            -- 		place_category = "",
            -- 		place_type = "",
            -- 		index = 1,
            -- 		use_access_node = false|true,
            -- 		try_alternative_if_used = true|false
            -- }
            local index = pos.index or 1
            local use_access_node = pos.use_access_node or false
            local try_alternative_if_used = pos.try_alternative_if_used or false
            local places = npc.places.get_by_type(self, pos.place_type)
            --minetest.log("Place type: "..dump(pos.place_type))
            --minetest.log("Places: "..dump(places))
            -- Check index is valid on the places map
            if #places >= index then
                local place = places[index]
                -- Check if place is used, and if it is, find alternative if required
                if try_alternative_if_used == true then
                    place = npc.places.find_unused_place(self, pos.place_category, pos.place_type, place)

                    --minetest.log("Mark as used? "..dump(pos.mark_target_as_used))
                    if pos.mark_target_as_used == true then
                        --minetest.log("Marking as used: "..minetest.pos_to_string(place.pos))
                        npc.places.mark_place_used(place.pos, npc.places.USE_STATE.USED)
                    end

                    npc.places.add_shared_accessible_place(
                        self, {owner="", node_pos=place.pos}, npc.places.PLACE_TYPE.CALCULATED.TARGET, true, {})
                end
                -- Check if access node is desired
                if use_access_node == true then
                    -- Return actual node pos
                    return place.access_node, place.pos
                else
                    -- Return node pos that allows access to node
                    return place.pos
                end
            end
        end
    elseif type(pos) == "string" then
        -- Received name of place, so we are going to look for the actual pos
        local places_pos = npc.places.get_by_type(self, pos, false)
        -- Return nil if no position found
        if places_pos == nil or #places_pos == 0 then
            return nil
        end
        -- Check if received more than one position
        if #places_pos > 1 then
            -- Check all places, return owned if existent, else return the first one
            for i = 1, #places_pos do
                if places_pos[i].status == "owned" then
                    if use_access_node == true then
                        return places_pos[i].access_node, places_pos[i].pos
                    else
                        return places_pos[i].pos
                    end
                end
            end
        end
        -- Return the first position only if it couldn't find an owned
        -- place, or if it there is only one
        if use_access_node == true then
            return places_pos[1].access_node, places_pos[1].pos
        else
            return places_pos[1].pos
        end
    end
end

-- This function allows a NPC to use a furnace using only items from
-- its own inventory. Fuel is not provided. Once the furnace is finished
-- with the fuel items the NPC will take whatever was cooked and whatever
-- remained to cook. The function received the position of the furnace
-- to use, and the item to cook in furnace. Item is an itemstring
function npc.commands.use_furnace(self, args)
    local pos = get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_furnace' using args.pos: "..dump(args.pos))
        return
    end

    local enable_usage_marking = args.enable_usage_marking or true
    local item = args.item
    local freeze = args.freeze
    -- Define which items are usable as fuels. The NPC
    -- will mainly use this as fuels to avoid getting useful
    -- items (such as coal lumps) for burning
    local fuels = {"default:leaves",
        "default:pine_needles",
        "default:tree",
        "default:acacia_tree",
        "default:aspen_tree",
        "default:jungletree",
        "default:pine_tree",
        "default:coalblock",
        "farming:straw"}

    -- Check if NPC has item to cook
    local src_item = npc.inventory_contains(self, npc.get_item_name(item))
    if src_item == nil then
        -- Unable to cook item that is not in inventory
        return false
    end

    -- Check if NPC has a fuel item
    for i = 1,9 do
        local fuel_item = npc.inventory_contains(self, fuels[i])

        if fuel_item ~= nil then
            -- Get fuel item's burn time
            local fuel_time =
            minetest.get_craft_result({method="fuel", width=1, items={ItemStack(fuel_item.item_string)}}).time
            local total_fuel_time = fuel_time * npc.get_item_count(fuel_item.item_string)
            npc.log("DEBUG", "Fuel time: "..dump(fuel_time))

            -- Get item to cook's cooking time
            local cook_result =
            minetest.get_craft_result({method="cooking", width=1, items={ItemStack(src_item.item_string)}})
            local total_cook_time = cook_result.time * npc.get_item_count(item)
            npc.log("DEBUG", "Cook: "..dump(cook_result))

            npc.log("DEBUG", "Total cook time: "..total_cook_time
                    ..", total fuel burn time: "..dump(total_fuel_time))

            -- Check if there is enough fuel to cook all items
            if total_cook_time > total_fuel_time then
                -- Don't have enough fuel to cook item. Return the difference
                -- so it may help on trying to acquire the fuel later.
                -- NOTE: Yes, returning here means that NPC could probably have other
                -- items usable as fuels and ignore them. This should be ok for now,
                -- considering that fuel items are ordered in a way where cheaper, less
                -- useless items come first, saving possible valuable items.
                return cook_result.time - fuel_time
            end

            -- Set furnace as used if flag is enabled
            if enable_usage_marking then
                -- Set place as used
                npc.places.mark_place_used(pos, npc.places.USE_STATE.USED)
            end

            -- Calculate how much fuel is needed
            local fuel_amount = total_cook_time / fuel_time
            if fuel_amount < 1 then
                fuel_amount = 1
            end

            npc.log("DEBUG", "Amount of fuel needed: "..fuel_amount)

            -- Put this item on the fuel inventory list of the furnace
            local args = {
                player = nil,
                pos = pos,
                inv_list = "fuel",
                item_name = npc.get_item_name(fuel_item.item_string),
                count = fuel_amount
            }
            npc.add_action(self, npc.commands.cmd.PUT_ITEM, args)
            -- Put the item that we want to cook on the furnace
            args = {
                player = nil,
                pos = pos,
                inv_list = "src",
                item_name = npc.get_item_name(src_item.item_string),
                count = npc.get_item_count(item),
                is_furnace = true
            }
            npc.add_action(self, npc.commands.cmd.PUT_ITEM, args)

            -- Now, set NPC to wait until furnace is done.
            npc.log("DEBUG", "Setting wait command for "..dump(total_cook_time))
            npc.add_action(self, npc.commands.cmd.SET_INTERVAL, {interval=total_cook_time, freeze=freeze})

            -- Reset timer
            npc.add_action(self, npc.commands.cmd.SET_INTERVAL, {interval=1, freeze=true})

            -- If freeze is false, then we will have to find the way back to the furnace
            -- once cooking is done.
            if freeze == false then
                npc.log("DEBUG", "Adding walk to position to wandering: "..dump(pos))
                npc.add_task(self, npc.commands.cmd.WALK_TO_POS, {end_pos=pos, walkable={}})
            end

            -- Take cooked items back
            args = {

                player = nil,
                pos = pos,
                inv_list = "dst",
                item_name = cook_result.item:get_name(),
                count = npc.get_item_count(item),
                is_furnace = false
            }
            npc.log("DEBUG", "Taking item back: "..minetest.pos_to_string(pos))
            npc.add_action(self, npc.commands.cmd.TAKE_ITEM, args)

            npc.log("DEBUG", "Inventory: "..dump(self.inventory))

            -- Set furnace as unused if flag is enabled
            if enable_usage_marking then
                -- Set place as used
                npc.places.mark_place_used(pos, npc.places.USE_STATE.NOT_USED)
            end

            return true
        end
    end
    -- Couldn't use the furnace due to lack of items
    return false
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, command can be lay or get up
function npc.commands.use_bed(self, args)
    local pos = get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_bed' using args.pos: "..dump(args.pos))
        return
    end
    local command = args.command
    local enable_usage_marking = args.enable_usage_marking or true
    local node = minetest.get_node(pos)
    --minetest.log(dump(node))
    local dir = minetest.facedir_to_dir(node.param2)

    if command == npc.commands.const.beds.LAY then
        -- Get position
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        local bed_pos = npc.commands.nodes.beds[node.name].get_lay_pos(pos, dir)
        -- Sit down on bed, rotate to correct direction
        npc.add_action(self, npc.commands.cmd.SIT, {pos=bed_pos, dir=(node.param2 + 2) % 4})
        -- Lay down
        npc.add_action(self, npc.commands.cmd.LAY, {})
        if enable_usage_marking then
            -- Set place as used
            npc.places.mark_place_used(pos, npc.places.USE_STATE.USED)
        end
        self.commands.move_state.is_laying = true
    else
        -- Calculate position to get up
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        local bed_pos_y = npc.commands.nodes.beds[node.name].get_lay_pos(pos, dir).y
        local bed_pos = {x = pos.x, y = bed_pos_y, z = pos.z}
        -- Sit up
        npc.add_action(self, npc.commands.cmd.SIT, {pos=bed_pos})
        -- Initialize direction: Default is front of bottom of bed
        local dir = (node.param2 + 2) % 4
        -- Find empty node around node
        -- Take into account that mats are close to the floor, so y adjustmen is zero
        local y_adjustment = -1
        if npc.commands.nodes.beds[node.name].type == "mat" then
            y_adjustment = 0
        end

        local pos_out_of_bed = pos
        local empty_nodes = npc.places.find_node_orthogonally(bed_pos, {"air", "cottages:bench"}, y_adjustment)
        if empty_nodes ~= nil and #empty_nodes > 0 then
            -- Get direction to the empty node
            dir = npc.commands.get_direction(bed_pos, empty_nodes[1].pos)

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
        npc.add_action(self, npc.commands.cmd.STAND, {pos=pos_out_of_bed, dir=dir})
        if enable_usage_marking then
            -- Set place as unused
            npc.places.mark_place_used(pos, npc.places.USE_STATE.NOT_USED)
        end
        self.commands.move_state.is_laying = false
    end
end

-- This function makes the NPC lay or stand up from a bed. The
-- pos is the location of the bed, command can be lay or get up
function npc.commands.use_sittable(self, args)
    local pos = get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_sittable' using args.pos: "..dump(args.pos))
        return
    end
    local command = args.command
    local enable_usage_marking = args.enable_usage_marking or true
    local node = minetest.get_node(pos)

    if command == npc.commands.const.sittable.SIT then
        -- Calculate position depending on bench
        -- Error here due to ignore. Need to come up with better solution
        if node.name == "ignore" then
            return
        end
        local sit_pos = npc.commands.nodes.sittable[node.name].get_sit_pos(pos, node.param2)
        -- Sit down on bench/chair/stairs
        npc.add_action(self, npc.commands.cmd.SIT, {pos=sit_pos, dir=(node.param2 + 2) % 4})
        if enable_usage_marking then
            -- Set place as used
            npc.places.mark_place_used(pos, npc.places.USE_STATE.USED)
        end
        self.commands.move_state.is_sitting = true
    else
        if self.commands.move_state.is_sitting == false then
            npc.log("DEBUG_ACTION", "NPC "..self.npc_name.." attempted to get up from sit when it is not sitting.")
            return
        end
        -- Find empty areas around chair
        local dir = node.param2 + 2 % 4
        -- Default it to the current position in case it can't find empty
        -- position around sittable node. Weird
        local pos_out_of_sittable = pos
        local empty_nodes = npc.places.find_node_orthogonally(pos, {"air"}, 0)
        if empty_nodes ~= nil and #empty_nodes > 0 then
            --minetest.log("Empty nodes: "..dump(empty_nodes))
            --minetest.log("Npc.commands.get_direction: "..dump(npc.commands.get_direction))
            --minetest.log("Pos: "..dump(pos))
            -- Get direction to the empty node
            dir = npc.commands.get_direction(pos, empty_nodes[1].pos)
            -- Calculate position to get out of sittable node
            pos_out_of_sittable =
            {x=empty_nodes[1].pos.x, y=empty_nodes[1].pos.y + 1, z=empty_nodes[1].pos.z}
        end
        -- Stand
        npc.add_action(self, npc.commands.cmd.STAND, {pos=pos_out_of_sittable, dir=dir})
        minetest.log("Setting sittable at "..minetest.pos_to_string(pos).." as not used")
        if enable_usage_marking then
            -- Set place as unused
            npc.places.mark_place_used(pos, npc.places.USE_STATE.NOT_USED)
        end
        self.commands.move_state.is_sitting = false
    end
end

-- This function returns the direction enum
-- for the moving from v1 to v2
function npc.commands.get_direction(v1, v2)
    local vector_dir = vector.direction(v1, v2)
    local dir = vector.round(vector_dir)

    if dir.x ~= 0 and dir.z ~= 0 then
        if dir.x > 0 and dir.z > 0 then
            return npc.direction.north_east
        elseif dir.x > 0 and dir.z < 0 then
            return npc.direction.south_east
        elseif dir.x < 0 and dir.z > 0 then
            return npc.direction.north_west
        elseif dir.x < 0 and dir.z < 0 then
            return npc.direction.south_west
        end
    elseif dir.x ~= 0 and dir.z == 0 then
        if dir.x > 0 then
            return npc.direction.east
        else
            return npc.direction.west
        end
    elseif dir.z ~= 0 and dir.x == 0 then
        if dir.z > 0 then
            return npc.direction.north
        else
            return npc.direction.south
        end
    end
end


-- This function can be used to make the NPC walk from one
-- position to another. If the optional parameter walkable_nodes
-- is included, which is a table of node names, these nodes are
-- going to be considered walkable for the algorithm to find a
-- path.
function npc.commands.walk_to_pos(self, args)
    -- Get arguments for this task
    local use_access_node = args.use_access_node or true
    local end_pos, node_pos = get_pos_argument(self, args.end_pos, use_access_node)
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
            local dir = npc.commands.get_direction(end_pos, node_pos)
            npc.add_action(self, npc.commands.cmd.STAND, {dir = dir})
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
        self.commands.walking.path = path

        -- Local variables
        local door_opened = false
        local speed = npc.commands.two_nps_speed

        -- Set the command timer interval to half second. This is to account for
        -- the increased speed when walking.
        npc.add_action(self, npc.commands.cmd.SET_INTERVAL, {interval=0.5, freeze=true})

        -- Set the initial last and target positions
        self.commands.walking.target_pos = path[1].pos

        -- Add steps to path
        for i = 1, #path do
            -- Do not add an extra step if reached the goal node
            if (i+1) == #path then
                -- Add direction to last node
                local dir = npc.commands.get_direction(path[i].pos, end_pos)
                -- Add the last step
                npc.add_action(self, npc.commands.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+1].pos})
                -- Add stand animation at end
                if use_access_node == true then
                    dir = npc.commands.get_direction(end_pos, node_pos)
                end
                minetest.log("Dir: "..dump(dir))
                -- Change dir if using access_node
                npc.add_action(self, npc.commands.cmd.STAND, {dir = dir})
                break
            end
            -- Get direction to move from path[i] to path[i+1]
            local dir = npc.commands.get_direction(path[i].pos, path[i+1].pos)
            -- Check if next node is a door, if it is, open it, then walk
            if path[i+1].type == npc.pathfinder.node_types.openable then
                -- Check if door is already open
                local node = minetest.get_node(path[i+1].pos)
                if npc.commands.get_openable_node_state(node, path[i+1].pos,  dir) == npc.commands.const.doors.state.CLOSED then
                    --minetest.log("Opening command to open door")
                    -- Stop to open door, this avoids misplaced movements later on
                    npc.add_action(self, npc.commands.cmd.STAND, {dir=dir})
                    -- Open door
                    npc.add_action(self, npc.commands.cmd.USE_OPENABLE, {pos=path[i+1].pos, dir=dir, command=npc.commands.const.doors.command.OPEN})

                    door_opened = true
                end

            end

            -- Add walk command to command queue
            npc.add_action(self, npc.commands.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+1].pos})

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
                -- npc.add_action(self, npc.commands.cmd.WALK_STEP, {dir = dir, speed = speed, target_pos = path[i+2].pos})
                -- Stop to close the door
                npc.add_action(self, npc.commands.cmd.STAND, {dir=(dir + 2) % 4 })--, pos=pos_on_close})
                -- Close door
                npc.add_action(self, npc.commands.cmd.USE_OPENABLE, {pos=path[i+1].pos, command=npc.commands.const.doors.command.CLOSE})

                door_opened = false
            end

        end

        -- Return the command interval to default interval of 1 second
        -- By default, always freeze.
        npc.add_action(self, npc.commands.cmd.SET_INTERVAL, {interval=1, freeze=true})

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