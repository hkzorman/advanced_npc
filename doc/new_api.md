Advanced NPC 1.0 proposal
-------------------------

While Advanced NPC provides functionality and a level of intelligence that no other mob mod can, it is still limited in some features and to its ultimate purpose of creating functional towns and/or simulated communities. The following are the areas that has been identified as lacking:

  - Idle/wandering
    - When NPCs aren't executing actions, their movement is very dumb. They wander aimlessly, constantly and usually bump into obstacles and keep walking nevertheless. They get stuck at places they shouldn't.
  - Relationships
  	- Relationships are very hardcoded, and there's no flexibility on them.
  - Unable to add more functionality
  	- All actions are hardcoded. While the essentials are in, making a NPC operate another node that is not a furnace/chest/door is almost impossible. If a mod adds a node and wants NPC to be able to operate it, it is certainly very hard.
  - More randomness in schedules
  	- While schedules are all about making NPCs do actions at certain times, it is not flexible enough to make it look more realistic. One morning a NPC can get up and make breakfast or not, put some music on a music player or not, go outside their home and wander around, etc.
  - Unable to react to certain triggers
    - When NPCs are punched, `mobs_redo` takes over and controls the NPC. Also, NPCs are unable to scan an area for certain things and perform actions continually based on it. 

The above are all playability issues and deficiencies. Some technical issues has to be addressed as well regarding the API. Given all these, the following is a proposal to move the mod towards the correct direction.


##Proposed changes:
  - Unify the actions/tasks/schedule property change/schedule query API into a `commands` API
  - Add new commands to bring the NPC interaction level closer to that of a player
  - Rename `flags` to `properties`
  - Allow registering scripts, or collections of commands for external mods to provide extra functionality


Unified Commands API
--------------------

The goal of this API is to provide consistency and extensibility to the actions a NPC can perform. First of all, rename actions/tasks/property change/query to `commands`. Each command will have the following properties that determines how it is to be executed and what it does:

  - Type: specifies the type of command. The following are valid types:
    - `instruction`: Used for fundamental, atomic operations. This type maps directly to what are called now `actions`, which are for example, walk one step, dig, place, etc.
    - `control`: Used for specific commands that are flow control statements. Example: If-else, for loops. The conditional statements is a Lua boolean expression.
    - `script`: Used for collections of commands, executed on a sequential structure. This type maps directly to `tasks`.
  - Execution: specifies how the command is to be executed. The following are valid valuesf for this parameter:
    - `immediate`: Will execute this command immediately, without any enqueing. Very little commands should be able to do this. The `control` commands should be executed immediately as they need to enqueue certain commands depending on their conditions.
    - `default`: Command will be enqueued and executed on the global command timer call.
  - Interruptable: specifies whether the global command timer and/or the scheduler can interrupt the command. Boolean value, can be set to false or true.
    - _Important_: Non-interruptable commands should be able to finish by themselves. The API will execute the default command once a non-interruptable command is done and if it doesn't executes another command.
  - Parameters: a Lua table with all the parameters that the command requires. Depending on the type, some parameters are required. Below is a list of required parameters per type:
    - `instruction`: Requires just the parameters required by the instruction to execute. 
    - `control`: Requires different parameters depending on the type of control.
      - Required:
      	- `condition`: The condition to be evaluated. This is a Lua boolean expression.
      	- `match_commands`: A Lua array with the commands to be executed if condition evaluates to `true`.
      - Dependent on type:
        - `operation`: Only required in `for-loop` command. Operation to execute on the loop variable (e.g. increase/decrease)
        - `repetition`: Optional for `for-loop` command. Can't be used together with `max` and `min`.
        - `max`: Optional for `for-loop` command. Can't be used together with `repetition`. Requires `min`. Randomizes a loop execution and sets the upper bound of how many times the loop will execute.
        - `min`: Optional for `for-loop` command. Can't be used together with `repetition`. Requires `max`. Randomizes a loop execution and sets the lower bound of how many times the loop will execute.
        - `else_commands`: Only required in `if-else` command. A Lua array with the commands to be executed if condition evaluates to `false`. 
    - `script`: A Lua array of commands to execute, in order

The following `instruction` commands will be added to the default set:
  - `do_punch`: Executes the `on_punch` function of a node, object or player
  - `do_rightclick`: Executes the `on_rightclick` function of a node, object or player
  - `set_property`: Sets the value of a variable in the `self.properties` object. If the variable doesn't exists, it is created. This command is executed immediately and is not enqueued.
    - Parameters:
      - `key`: The property key-name. This is a variable in the `self.properties` object
      - `value`: The property value.
  - `get_property`: Returns the value of a given property. This command is executed immediately and is not enqueued.
    - Parameters:
  	  - `key`: The property key-name.
  - `set_internal_property`: Sets the value of a limited set of internal properties related to the NPC trading and personality variables.
  - `get_internal_property`: Gets the value of a limited set of internal properties related to the NPC trading and personality variables.
  - `add_item_to_npc`: Adds an item to the NPC inventory, without any specific source.
  - `remove_item_from_npc`: Removes a specific item from the NPC inventory.
  - `query`: Executes a query for nodes or objects. Returns a Lua table with none, single or many positions. 

The following `control` commands will be added to the default set:
  - `if-else`: An if-else control statement that will execute immediately. It will evaluate the given `condition` parameter and execute commands depending on the evaluation of the `condition`.
    - Parameters:
      - `condition`: A Lua boolean expression to be evaluated.
      - `true-commands`: A Lua array of commands to be executed if `condition` evaluates to `true`.
      - `else-commands`: A Lua array of commands to be executed if `condition` evaluates to `false`.
  - `loop`: A flexible loop command. Supports for-loop and while-loops. The amount of loops done will be available in `npc.commands.current_loop_count`. Executes immediately, it is not enqueued.
    - Parameters:


##Extensibility
Once the above commands has been added, it is possible to safely build scripts which don't touch directly many of the internal NPC mechanisms. An API will be provided for external mods to register scripts that let NPCs perform actions related to those mods, e.g. operating a node provided by the mod. The API for this will be:

`npc.commands.register_script(name, script)`

All registered scripts have the following properties:
  - They are interruptable by the command queue/scheduler
  - They are not immediately executed

The `script` parameter is a Lua array of commands that will be executed when the script is executed.