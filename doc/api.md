Advanced_NPC API Reference Alpha-2 (DEV)
=========================================
* More information at <https://github.com/hkzorman/advanced_npc/wiki>

IMPORTANT: This WIP & unfinished file contains the definitions of current advanced_npc functions
(Some documentation is lacking, so please bear in mind that this WIP file is just to enhance it)


Summary
-------
* Introduction
* Initialize NPC
* NPC Steps
* Programs
* Schedules
* Occupations
* Locations
* Dialogues
* Definition tables


Introduction
------------
You can consult this document for help on API of behaviors for the NPCs. 
The goal is to be able to have NPCs that have the same functionality as normal players.
The NPCs make Sokomine's mg_villages in Minetest alive although they can
be manually spawned outside the village and work as good as new. 
Here is some information about the API methods and systems.
* npc.lua also uses methods and functions from the dependency: mobs_redo <https://github.com/tenplus1/mobs_redo>

Initialize NPC
--------------
The API works with some variables into Lua Entity that represent a NPC, 
then you should initialize the Lua Entity before that it really assume 
a controled behavior.

### Methods
* `npc.initialize(entity, pos, is_lua_entity, npc_stats, occupation_name)` : Initialize a NPC

The simplest way to start a mob (of mobs_redo API) is by using the `on_spawn` function
Note: currently this call is unduly repeated (mobs_redo problem), so you should check if npc has already been initialized.

    on_spawn = function(self)
        if self.initialized == nil then
            npc.initialize(self, self.object:getpos(), true)
            self.tamed = false
        end
    end

Or after add in the world

    local obj = minetest.add_entity({x=0, y=10, z=0}, "mobs:sheep", {naked = true})
    local luaentity = get_luaentity(obj)
    npc.initialize(luaentity, luaentity.object:getpos(), true)
    luaentity.tamed = false


NPC Steps
---------
The API works with NPC steps, then `on_step` callback need run the 
`npc.on_step(luaentity)`. This function process the NPC actions 
and return the freeze state, which is used for stop mobs_redo behavior.

Example:

    on_step = function(self, dtime)
        npc.step(self, dtime)
    end

Mobs of Mobs_Redo API uses `do_custom` function instead of `on_step` callback
and it needs return the freeze state to stop mobs_redo behavior. 
Here is a recommended code.

    do_custom = function(self, dtime)
    	
        -- Here is my "do_custom" code
    	
        -- Process the NPC action and return freeze state
        return npc.step(self, dtime)
    end


Execution API
-------------
The API follows a simple OS-based model where tasks performed by NPCs are encapsulated
in the concepts of `instructions` and `programs`. `Instructions` are "small", "atomic"
actions performed by a NPC (like rotating, standing, etc.) and `programs` are a
"collection" of instructions with logic on what to execute and what not (for example,
walking to a specific position). The NPC executes different programs in order to be
able to perform tasks (e.g. going to sleep on a bed).

The execution environment of Advanced NPC is based on processes, which are instances
of a program. Processes have an internal instruction queue and execution context for
storing variables; they can be interrupted and their state upon interruption is
stored for later restoration. Processes can also be enqueued into a process queue
which is managed by a process scheduler (which runs roughly each second). The process
scheduler has the responsibility of determining what is the next process to be executed.

### State processes
A very important concept introduced by the execution environment are `state processes`.
A state process is used to determine the actions of a NPC on a given state. The usual
examples for states are:
  - idle
  - wandering
  - following an object
  - attacking

All of the above `states` are actions that have similar properties:
  - Triggered by a particular action, e.g. NPC is punched (attack state) or NPC is sleeping (idle state)
  - Executed constantly until a particular goal is reached or more important action takes place

Therefore, a `state process` is a special type of process that is executed constantly while
the process queue is empty.

### Operation principle
Note: The information in this subtopic should not be considered for external development,
only for knowledge about the principle of internal operation.

A process is an instance of a program, with the following attributes:
  * A state, which can be any of:
    * inactive: process that was just enqueued
    * executing: process' Lua function is being executed and not finished yet
    * running: process finished execution, and may or may not have instructions on its queue
    * paused: interrupted process
    * ready: process was interrupted, and then restored, it is ready to run again
    * waiting_user_input: happens when on_rightclick interaction occurs
  * An instruction_queue, where instructions are enqueued and executed over time. 
    In terms of OS, think of this as some kind of program counter
  * An execution_context, which is the data space of the process. 
    The execution context is a map of key-value pairs, 
    supporting read-only values (can't be updated again).
  * An interrupted_process, in case that this process interrupted a previous one, 
    so that it can restored exactly as it was
  * An instruction state, where the current instruction being executed is stored as well as its state 
    (so it can be re-executed in case process is interrupted)

The process definition is in private `_exec.create_process_entry()` function. This is like this so a process 
is always complete and ensured to have all its attributes. The proper way to create a process entry and enqueue
it into the NPC's process queue is by using the `npc.exec.enqueue_program()`.

The process definition (as Lua table) is the following:

   {
        id = process_id,
        program_name = program_name,
        arguments = arguments,
        state = npc.exec.proc.state.INACTIVE,
        execution_context = {
            data = {},
            instr_interval = 1,
            instr_timer = 0
        },
        instruction_queue = {},
        current_instruction = {
            entry = {},
            state = npc.exec.proc.instr.state.INACTIVE,
            pos = {}
        },
        interrupt_options = npc.exec.create_interrupt_options(interrupt_options),
        interrupted_process = {},
        is_state_process = is_state_program
    }

The state process have an additional attribute and is_state_process is set to true:

    state_process_id = os.time()

### Writing and registering programs
Programs are  just a Lua function.
Many examples of programs can be found on the code, but the following
are some general tips to keep in mind while writing programs
* If you are doing anything that needs to be done in the future 
  (example, walking and then checking a node), run the initial instruction and enqueue 
  the rest.
* The correct way to run a program from a program is to use `advanced_npc:interrupt`
* If you need to evaluate any value in the future (example, after movement), store 
  it in a process variable (see the `npc.exec.var*` functions)
* You can use instruction recursion to do loops.
* If you are writing any state program, do not make it loop. It will loop for free 
  (scheduler will execute again and again, so your variables are not lost)
* And finally, if your process is simple, don't enqueue any instruction unless you 
  want to have a certain pause between instruction execution for visual reasons 
  (e.g NPC sitting to laying, everythig executed quickly will not look nice)

### Permanent storage functionality
Permanent storage functionality - create, read, update and delete variables 
in the NPC's permnanent storage.
IMPORTANT: These variables are *NOT* deleted. Be careful what you store on it or 
the NPC object can grow in size very quickly. 
For temporary storage, use `npc.exec.var.*` functions.

#### Methods
* `npc.data.put(luaentity, key_name, value, readonly)`: This function adds a value to the permanent data storage in the Lua entity
  * Readonly defaults to false. 
  * Returns false if failed due to key_name conflict, or returns true if successful.
* `npc.data.get(luaentity, key_name)`: Returns the value of a given key. If not found returns nil
* `npc.data.set(luaentity, key_name, new_value)`: This function updates a value in the permanent data storage
  * Returns false if the value is read-only or if key isn't found.
  * Returns true if able to update value.
* `npc.data.remove(luaentity, key_name)`: This function removes a value in the permanent data storage in the Lua entity
  * If the key doesn't exist, returns nil, otherwise, returns the value removed.

### Variable functionality
Variable functionality - create, read, update and delete variables in the
current process.
IMPORTANT: These variables are deleted when the process is finished execution.
For permanent storage, use `npc.data.*` functions.

#### Methods
* `npc.exec.var.put(luaentity, key_name, value, readonly)`: Put a value to the execution context of the current process
  * Readonly defaults to false
  * Returns false if failed due to key_name conflict, or returns true if successful
* `npc.exec.var.get(luaentity, key_name)`: Returns the value of a given key
  * If not found returns nil
* `npc.exec.var.set(luaentity, key_name, new_value)`: Update a value in the execution context
  * Returns false if the value is read-only or if key isn't found
  * Returns true if able to update value
* `npc.exec.var.remove(luaentity, key_name)`: Remove a variable from the execution context
  * If the key doesn't exist, returns nil, otherwise, returns the value removed

### Methods
* `npc.programs.register(program_name, func)`: Register a program
* `npc.programs.is_registered(program_name)`: Check if a program exists
* `npc.programs.execute(luaentity, program_name, {program arguments})`: Execute a program for a NPC
* `npc.programs.instr.register(name, func)`: Register a instruction
* `npc.programs.instr.execute(self, name, args)`: Execute a instruction for a NPC
* `npc.exec.enqueue_program(luaentity, program_name, {program arguments}, interrupt_options, is_state_program)`: Add program to schedule queue
* `npc.exec.proc.enqueue(luaentity, instruction_name, {instruction arguments})`: Add instruction to process queue
* `npc.exec.var.put(luaentity, key_name, value, readonly)`: Put a value to the execution context of the current process
* `npc.exec.var.get(luaentity, key_name)`: Returns the value of a given key_name
* `npc.exec.var.set(luaentity, key_name, new_value)`: Update a value in the execution context
* `npc.exec.var.remove(luaentity, key_name)`: Remove a variable from the execution context
* `npc.data.put(luaentity, key_name, value, readonly)`: This function adds a value to the permanent data storage in the Lua entity
* `npc.data.get(luaentity, key_name)`: Returns the value of a given key
* `npc.data.set(luaentity, key_name, new_value)`: This function updates a value in the permanent data storage in the Lua entity
* `npc.data.remove(luaentity, key_name)`: This function removes a value from the permanent data storage in the Lua entity

Example 1
    
    npc.programs.execute(self, "advanced_npc:walk_to_pos", {
        end_pos = {x=0,y=0,z=0},
        walkable = {}
    })

See more about different programs and his arguments in [programs.md](programs.md) documentation.

Example 2

    -- Syntacic sugar to make a process wait for a specific interval
    npc.programs.instr.register("advanced_npc:wait", function(self, args)
        local wait_time = args.time
        npc.programs.instr.execute(self, "advanced_npc:set_instruction_interval", {interval = wait_time - 1})
        npc.exec.proc.enqueue(self, "advanced_npc:set_instruction_interval", {interval = 1})
    end)

See more about different instructions and his arguments in [instructions.md](instructions.md) documentation.

### Monitoring API
To complete the OS/microprocessor analogy, the Execution API has a sub-API for registering
timers and callbacks of certain events. This API is called "monitor" API because its main
purpose is to be able to keep track of actions that the NPC performs and act according to this
data. The key concept behind the Monitoring API is to be able to introduce some concepts of
artificial intelligence into the Advanced NPC programs.

#### Timers
Timers can be registered (globally on the `npc.*` namespace) and then added to a NPC for
execution. To register a timer, use:
`npc.monitor.timer.register(name, interval, callback)`
where:
  - `name` is a unique name for the timer. Recommended naming convention to use: `<modname>:<related_program_name>:<timer_name>`
  - `interval`: the default interval, this can be overriden
  - `callback`: a Lua function that is called with `self` (the NPC Lua entity) and a Lua table `args` for arguments

To run a timer, a new instance is created for the particular NPC that will use the timer
and then it is executed internally. The following function is used to start a timer:
`npc.monitor.timer.start(self, name, interval, args)`
where:
  - `name` is the unique name of the timer
  - `interval` optional, interval for the timer (if nil, uses the default interval)
  - `args` a Lua table of arguments for the timer callback

To stop a timer, simply use:
`npc.monitor.timer.stop(self, name)`

##### A word of caution with timers:
While timers can be very useful, they can also be very disruptive, specially if they are
changing state process. Therefore, every timer `callback` function *should* have a condition
check at the very beginning before anything else runs. This way, if the condition for the timer
is no longer valid, it stops and doesn't interferes with other processes running.

#### Callbacks
Callbacks are functions executed whenever another action is executed. All callbacks
execute *after* the actual action. Currently, there are three types of callbacks supported:
  - Program callback: executed whenever a program is executed
  - Instruction callback: executed whenever a instruction is executed
  - Interaction callback: executed whenever a interaction occurred, which are:
    - on punch,
    - on right-click
    - on schedule

Callbacks are categorized in terms of `type` (mentioned above) and `subtype`. For programs and
instruction callbacks, the `subtype` is the program or instruction name.
For interaction callbacks, the subtypes are predetermined (as shown above).

To register a callback, use:
`npc.monitor.callback.register(name, type, subtype, callback)`
where:
  - `name` is a unique name for the callback
  - `type` is one of the three callback types (defined in `npc.monitor.callback.type`),
  - `subtype` is an arbitrary string that denotes the program or instruction name for `program` and `instruction` callbacks respectively, or one of the three subtypes (defined in `npc.monitor.callback.subtype`) as mentioned above for `interaction` callbacks
  - `callback` is the function to be executed. The only argument of this function is `self` (the NPC Lua entity)

To execute a callback, use:
`npc.monitor.callback.enqueue(self, type, subtype, name)`

Or to enqueue all callbacks for a specific `type` and `subtype`, do:
`npc.monitor.callback.enqueue_all(self, type, subtype)`


Schedules
---------
The interesting part of Advanced NPC is its ability to simulate realistic 
behavior in NPCs. Realistic behavior is defined simply as being able to 
perform tasks/programs at a certain time of the day, like usually people do. 
This allow the NPC to go to bed, sleep, get up from it, sit in benches, etc. 
All of this is simulated through a structured code using programs for action 
and tasks.

The implementation resembles a rough OS process scheduling algorithm where 
only one process is allowed at a time. The processes or tasks are held in 
a queue, where they are executed one at a time in queue fashion. 
Interruptions are allowed, and the interrupted action is re-started once 
the interruption is finished.

### Schedule time
Only integer value 0 until 23
* 0: 0/24000 - 999
* 1: 1000 - 1999
* 2: 2000 - 2999
* ...
* 22: 22000 - 22999
* 23: 23000 - 23999

### Schedule Type
* "generic" : Returns nil if there are already seven schedules, one for each 
  day of the week or if the schedule attempting to add already exists. 
  The date parameter is the day of the week it represents as follows:
    Note: Currently only one schedule is supported, for day 0
    1: Monday
    2: Tuesday
    3: Wednesday
    4: Thursday
    5: Friday
    6: Saturday
    7: Sunday
* "date_based" : The date parameter should be a string of the format "MM:DD". 
  If it already exists, function retuns nil

### Methods
* `npc.schedule.create(luaentity, schedule_type, day)` : Create a schedule for a NPC
* `npc.schedule.delete(luaentity, schedule_type, date)` : Delete a schedule for a NPC
* `npc.schedule.entry.put(luaentity, schedule_type, date, time, check, commands)` : Add a schedule entry for a time
* `npc.schedule.entry.get(luaentity, schedule_type, date, time)` : Get a schedule entry
* `npc.schedule.entry.set(luaentity, schedule_type, date, time, check, commands)` : Update a schedule entry

### Examples

    -- Schedule entry for 7 in the morning
    npc.schedule.entry.put(self, "generic", 0, 7, nil, {
        -- Get out of bed
        [1] = {
            program_name = "schedules:default:wake_up",
            arguments = {},
            interrupt_options = {}
        },
        -- Walk to home inside
        [2] = {
            program_name = "advanced_npc:walk_to_pos",
            arguments = {
                end_pos = npc.locations.PLACE_TYPE.OTHER.HOME_INSIDE,
                walkable = {}
            },
            interrupt_options = {},
        },
    })


Occupations
-----------
NPCs need an occupation or job in order to simulate being alive.
This functionality is built on top of the schedules functionality.
Occupations are essentially specific schedules, that can have slight
random variations to provide diversity and make specific occupations
less predictable. Occupations are associated with textures, dialogues,
specific initial items, type of building (and surroundings) where NPC
lives, etc.

### Methods
* `npc.occupations.register_occupation(occupation_name, {occupation definition})` : Register an occupation
* `npc.occupations.initialize_occupation_values(luaentity, occupation_name)` : Initialize an occupation for a NPC


Locations
----------
Locations define which NPCs can access which places and are separated into different types.

### Locations types
Current location types
* `bed_primary` : the bed of a NPC 
* `sit_primary`
* `sit_shared`
* `furnace_primary`
* `furnace_shared`
* `storage_primary`
* `storage_shared`
* `home_entrance_door`
* `schedule_target_pos` : used in the schedule actions
* `calculated_target_pos`
* `workplace_primary`
* `workplace_tool`
* `home_plotmarker`
* `home_inside`
* `home_outside`

### Methods
* `npc.locations.add_owned(luaentity, place_name, place_type, pos, access_pos)` : Add owned place.
  `luaentity` npc owner.
  `place_name` a specific place name.
  `place_type` place typing. 
  `pos` is a position of a node to be owned.
  `access_pos` is the coordinate where npc must be to initiate the access.
  Location is added for the NPC.
* `npc.locations.add_shared(luaentity, place_name, place_type, pos, access_node)` : Add shared place


Dialogues
---------
Dialogs can be registered to be spoken by NPCs.

### Tags
The flags or marks of the dialogue text. Tags can be used for ....

* "unisex" : Both male and female NPCs can say the defined text.
* "phase1" : NPCs in phase 1 of a relationship can say the defined text. 

### Methods
* `set_response_ids_recursively()` : A local function that assigns unique 
  key IDs to dialogue responses.
* `npc.dialogue.register_dialogue({dialogue definition})` : Defines and 
  registers dialogues.
* `npc.dialogue.search_dialogue_by_tags({search_tags})` : A method returning 
  a Lua table of dialogues if called.


Definition tables
-----------------

### Program definition (Programs)

    {
        program_name = "modname:program1", -- Programs name
        
        arguments = {program arguments}, -- Lua table of arguments for the program
        
        is_state_program = true, --[[
            ^ [OPTIONAL]
            ^ If this is true, then this program will be 
              repeated while there is no next program]]
        
        interrupt_options = {} --[[
            ^ [OPTIONAL] 
            ^ Is a Lua table that defines what kind of interaction can interrupt the process 
              when it is running. The "interruption" is not a literal process pause. 
              It means that the defined interactions can happe while the process is running. 
              In that fashion, for example, if the NPC is sleeping, talking (right click interaction) 
              to the NPC can be disabled.
            ^ The three supported interaction types are defined below. 
              They are all optional and accept values of true or false 
                * allow_punch: if enabled, the entity's on_punch() function is executed.
                * allow_rightclick: if enabled, when the rightclick of the entitiy is called, 
                  the process is put on waiting_user_input state and entity's on_rightclick() executed
                * allow_schedule: enables or disables schedule entries. If disabled, schedule will not run.]]
        
        depends = {}, --[[ 
            ^ [OPTIONAL]
            ^ is an array of numbers, where each number represents an index in the array 
              of schedule entries for that time.
            ^ Is a schedule entry concept. For a certain time, an array of programs 
              is enqueued when the scheduled time arrives. The programs are enqueued 
              in the order they are given in the array. If a program have a chance argument, 
              it means that it could or couldn't happen. Therefore, some programs may or 
              may not run, hence the depends.
        
        chance = <number>, --[[
            ^ [OPTIONAL]
            ^ chance x in 100 of this program be executed
    }

### Occupation definition (`register_occupation`)

    {
        dialogues = {
            enable_gift_item_dialogues = true, --[[
                ^ This flag enables/disables gift item dialogues.
                ^ If not set, it defaults to true. ]]
            type = "", -- The type can be "given", "mix" or "tags"
            data = {}, --[[
                ^ Array of dialogue definitions. This will have dialogue
                  if the type is either "mix" or "given" ]]
            tags = {}, --[[
                ^ Array of tags to search for. This will have tags
                  if the type is either "mix" or "tags" ]]
        },
        
        textures = {}, --[[
            ^ Textures are an array of textures, as usually given on
              an entity definition. If given, the NPC will be guaranteed
              to have one of the given textures. Also, ensure they have sex
              as well in the filename so they can be chosen appropriately.
            ^ If left empty, it can spawn with any texture. ]]
            
        walkable_nodes = {}, -- Walkable nodes
        
        building_types = {}, --[[
            ^ An array of string where each string is the type of building
              where the NPC can spawn with this occupation.
            ^ Example: building_type = {"farm", "house"}
            ^ If left empty or nil, NPC can spawn in any building ]]
        
        surrounding_building_types = {}, --[[
            ^ An array of string where each string is the type of building
              that is an immediate neighbor of the NPC's home which can also
              be suitable for this occupation. Example, if NPC is farmer and
              spawns on house, then it has to be because there is a field
              nearby. 
            ^ If left empty or nil, surrounding buildings doesn't matter. ]]
        
        workplace_nodes = {}, --[[
            ^ An array of string where each string is a node the NPC works with. 
            ^ These are useful for assigning workplaces and work work nodes. ]]
        
        initial_inventory = {}, --[[
            ^ An array of entries like the following:
              {name="", count=1} -- or
              {name="", random=true, min=1, max=10}
            ^ This will initialize the inventory for the NPC with the given
              items and the specified count, or, a count between min and max
              when the entry contains random=true
            ^ If left empty, it will initialize with random items. ]]
        
        initial_trader_status = "", --[[
            ^ String that specifies initial trader value. 
            ^ Valid values are: "casual", "trader", "none" ]]
        
        schedules_entries = {},
            ^ This is a Lua  table of schedules where the index is a schedule time:
              {
                  [<schedule time>] = {
                      [1] = {program definition},
                      [2] = {program definition},
                      ...
                  },
                  [<schedule time>] = {
                      [1] = {program definition},
                      [2] = {program definition},
                      ...
                  },
                  ...
              }
    }

### Dialogue definition (`register_dialogue`)

    {
        text = "Hello.", --[[ 
        ^ The dialogue text itself. 
        ^ It must be included in the method.]]
        
        tags = {"tag1", "tag2"} --[[ 
        ^ The flags or marks of the dialogue text. 
        ^ The object can be excluded. ]]
    }

Examples: 

Syntax example 1:

    npc.dialogue.register_dialogue({
        text = "Hello.", -- "Hello." will be said by the NPC upon rightclick and displayed in the messages section.
        tags = {"unisex", "phase1"} -- The flags that define the conditions of who and what can say the text.
    })

Syntax example 2:

    npc.dialogue.register_dialogue({
        text = "Hello again."
        -- The tags object is excluded, meaning that any NPC can say "Hello again." upon rightclick under no condition.
    })
