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
* More information on advanced_npc methods in [actions_and_methods.md](doc/actions_and_methods.md)
* npc.lua also uses methods and functions from the dependency: mobs_redo <https://github.com/tenplus1/mobs_redo>


Initialize NPC
--------------
The API works with some variables into Lua Entity that represent a NPC, 
then you should initialize the Lua Entity before that it really assume 
a controled behavior.

### Methods
* `npc.initialize(entity, pos, is_lua_entity, npc_stats, occupation_name)` : Initialize a NPC

The simplest way to start a mob (of mobs_redo API) is by using the `on_spawn` function

    on_spawn = function(self)
        npc.initialize(self, self.object:getpos(), true)
        self.tamed = false
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
        npc.on_step(self)
    end

Mobs of Mobs_Redo API uses `do_custom` function instead of `on_step` callback
and it needs return the freeze state to stop mobs_redo behavior. 
Here is a recommended code.

    do_custom = function(self, dtime)
    	
        -- Here is my "do_custom" code
    	
        -- Process the NPC action and return freeze state
        return npc.on_step(self)
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

See more in [actions_and_methods.md](doc/actions_and_methods.md) documentation.


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


Places Map
----------
Places map define which NPCs can access which places.

### Methods
* `npc.places.add_owned(luaentity, place_name, place_type, pos, access_node)` : Add owned place.
  `pos` is a position of a node to be owned.
  `access_pos` is a position of a node to be accessed.
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

### Dialogue Definition (`register_dialogue`)

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
