Advanced_NPC API Reference Alpha-2 (DEV)
=========================================
* More information at <https://github.com/hkzorman/advanced_npc/wiki>

IMPORTANT: This WIP & unfinished file contains the definitions of current advanced_npc functions
(Some documentation is lacking, so please bear in mind that this WIP file is just to enhance it)

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


Actions and Tasks Queue
-----------------------
Actions are "atomic" executable actions the NPC can perform. Tasks are 
sequences of actions that are common enough to be supported by default.
Each action or task is wrapped on a Lua table which tells the action/task 
to be executed and the arguments to be used. However, this is encapsulated 
to the user in the following two methods for a NPCs:

### Methods
* `npc.add_action(luaentity, action, {action definition})`: Add action into NPC actions queue
* `npc.add_task(luaentity, task, {task definition})`: Add task into NPC actions queue

For both of the above, `action`/`task` is a constant defined in 
`npc.actions.cmd`, and `{task/action definition}` is a Lua table specific arguments 
to each `action`/`task`.

Example

    npc.add_task(self, npc.actions.cmd.USE_BED, {
        pos = {x=0,y=0,z=0},
        action = npc.actions.const.beds.LAY
    })
    npc.add_action(self, npc.actions.cmd.SET_INTERVAL, {
        interval = 10,
        freeze = true,
    })
    npc.add_task(self, npc.actions.cmd.USE_BED, {
        pos = {x=0,y=0,z=0},
        action = npc.actions.const.beds.GET_UP
    })

See more in [actions_and_tasks.md](actions_and_tasks.md) documentation.


Schedules
---------
The interesting part of Advanced NPC is its ability to simulate realistic 
behavior in NPCs. Realistic behavior is defined simply as being able to 
perform tasks at a certain time of the day, like usually people do. This 
allow the NPC to go to bed, sleep, get up from it, sit in benches, etc. 
All of this is simulated through a structured code using action and tasks.

The implementation resembles a rough OS process scheduling algorithm where 
only one process is allowed at a time. The processes or tasks are held in 
a queue, where they are executed one at a time in queue fashion. 
Interruptions are allowed, and the interrupted action is re-started once 
the interruption is finished.

### Schedule commands
Schedule commands are an array of actions and tasks that the NPC.
Exist 4 possible commands:

* action
```
    {
        action = action, -- Is a constant defined in `npc.actions.cmd`
        args = {} -- action arguments
    }
```
* task
```
    {
        task = task, -- Is a constant defined in `npc.actions.cmd`
        args = {} -- task arguments
    }
```
* Property change
```
    {
        ???
    }
```
* Schedule query/check
```
    {
        schedule query/check definition
    }
```
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
* `npc.create_schedule(luaentity, schedule_type, day)` : Create a schedule for a NPC
* `npc.delete_schedule(luaentity, schedule_type, date)` : Delete a schedule for a NPC
* `npc.add_schedule_entry(luaentity, schedule_type, date, time, check, commands)` : Add a schedule entry for a time
* `npc.get_schedule_entry(luaentity, schedule_type, date, time)` : Get a schedule entry
* `npc.update_schedule_entry(luaentity, schedule_type, date, time, check, commands)` : Update a schedule entry

### Examples

    -- Schedule entry for 7 in the morning
    npc.add_schedule_entry(self, "generic", 0, 7, nil, {
        -- Get out of bed
        [1] = {
            task = npc.actions.cmd.USE_BED, 
            args = {
                pos = "bed_primary",
                action = npc.actions.const.beds.GET_UP
           }
        },
        -- Allow mobs_redo wandering
        [2] = {
            action = npc.actions.cmd.FREEZE, 
            args = {
            	freeze = false
            }
        }
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

Places Map
----------
Places map define which NPCs can access which places.
Places are separated into different types.

### Place types
Current place types
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
* `npc.places.add_owned(luaentity, place_name, place_type, pos, access_pos)` : Add owned place.
  `luaentity` npc owner.
  `place_name` a specific place name.
  `place_type` place typing. 
  `pos` is a position of a node to be owned.
  `access_pos` is the coordinate where npc must be to initiate the access.
  Place is added for the NPC.
* `npc.places.add_shared(luaentity, place_name, place_type, pos, access_node)` : Add shared place


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
  a table of dialogues if called.


Definition tables
-----------------

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
            ^ This is a table of tables in the following format:
              {
                  [<time number>]  = {
                      [<command number>] = {
                          command
                      }
                  }
              }
            ^ Example:
            {
                [1] = {
                    [1] = schedule command
                },
                [13] = {
                    [1] = schedule command,
                    [2] = schedule command
                },
                [23] = {
                    [1] = schedule command
                }
            }
              The numbers, [1], [13] and [23] are the times when the entries
              corresponding to each are supposed to happen. The tables with
              [1], [1],[2] and [1] actions respectively are the entries that
              will happen at time 1, 13 and 23. ]]
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

### Schedule query/check definition (schedule command) 

    {
        check = true, -- Indicates that this is a schedule query/check
        
        range = 2, -- Range of checked area in blocks.
        
        count = 20, -- How many checks will be performed.
        
        random_execution_times = true, --[[
            ^ Randomizes the number of checks that will be performed.
            ^ min_count and max_count is required ]]
        
        min_count = 20, -- minimum of checks
        max_count = 25, -- maximum of checks
        
        nodes = {"itemstring1", "itemstring2"}, --[[ 
            ^ Nodes to be found for the actions.
            ^ When a node is found, it is add in the npc place map 
              with the place name "schedule_target_pos"
        
        prefer_last_acted_upon_node = true, -- If prefer to act on nodes already acted upon
        
        walkable_nodes = {"itemstring1", "itemstring2"}, -- Walkable nodes
        
        actions = { --[[
            ^ Table where index is a itemstring of the node to be found, 
              and value is an array of actions and tasks to be performed 
              when found the node. ]]
       	
            ["itemstring1"] = {            
               [1] = action or task in schedule command format,
               [2] = action or task in schedule command format,
               [3] = action or task in schedule command format
            },
            ["itemstring2"] = {            
               [1] = action or task in schedule command format,
               [2] = action or task in schedule command format
            }
        },
        
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
