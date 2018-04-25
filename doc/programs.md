Programs for Actions and Tasks
Advanced_NPC Alpha-2 (DEV)
==========================

IMPORTANT: In this documentation is only the explanation of the particular 
operation of each predefined action and task programs. Read reference documentation 
for details about API operation at [api.md](api.md).

### Default Programs
These programs are already registered in the API.
This section describes these programs and their respective arguments.

#### `IDLE` (advanced_npc:idle)
This program meant to be run when NPC are doing nothing and standing idle. 
Idle program doesn't loops, it is meant to be executed as a state program 
(which is scheduled continously as long as the process queue is empty)
It has two main features (as-of the moment, more planned):

    {
        acknowledge_nearby_objs = true, --[[
            ^ Acknowledge nearby objects by looking at them, 
              with configurable object search interval and radius]]
	wander_chance = 0, --[[
	    ^ Trigger wandering with configurable chance (1-100 chance of wander/0 for never) 
	      and radius (how many nodes to wander from starting point)]]
    }


#### `USE BED` (advanced_npc:use_bed) 
Sequence of actions that allows the NPC to use a bed.

    {
        pos = {x=0,y=0,z=0}, --[[
            ^ Position of bed to be used.
            ^ Can be a coordinate x,y,z.
            ^ Can be a place name of the NPC place map.
              Example: "bed_primary" ]]
        
        action = action, --[[ 
            ^ Whether to get up or lay on bed
            ^ Defined in npc.commands.const.beds.action
            ^ Available options:
              * npc.commands.const.beds.LAY : lay
              * npc.commands.const.beds.GET_UP : get up
    }

#### `WALK TO POS` (advanced_npc:walk_to_pos)
NPC will walk to the given position. This task uses the pathfinder to calculate the nodes 
in the path that the NPC will walk through, then enqueues walk_step actions, combined with 
correct directional rotations and opening/closing of doors on the path.

    {
        end_pos = {x=0,y=0,z=0}, --[[
            ^ Destination position to reach.
            ^ Can be a coordinate x,y,z.
            ^ Can be a place name of the NPC place map.
              The position must be walkable for the npc to stop in, 
              or in the access position of the place.
              Example: "home_inside" ]]
        
        walkable = {}, --[[
            ^ An array of node names to consider as walkable nodes 
              for finding the path to the destination. ]]
        
        use_access_node = true, --[[
            ^ Boolean, if true, when using places, it will find path 
              to the "accessible" node (empty or walkable node around 
              the target node) instead of to the target node. 
            ^ Default is true. ]]
        
        enforce_move = true, --[[
            ^ Boolean, if true and no path is found from the NPC's 
              position to the end_pos, the NPC will be teleported 
              to the destination (or, if use_access_node == true it will 
              teleport to the access position)
            ^ Default is true. ]]
    }

#### `INTERNAL PROPERTY CHANGE` (advanced_npc:internal_property_change)
Changes the value of an internal property of a NPC Lua entity.

    {
        property = <string>, --[[ 
          ^ Property type
          ^ Property types:
            "flag" for flags save in `flags` Lua table for in Lua entity]]
            
        args = {
        
            action = <string>, --[[
              ^ Type change action
              ^ Change types:
                "set" for set the value
                "reset" for reset the value 0 for number, false for boolean and "" for strings]]
                
            flag_name = <string>, -- Flag name
            flag_value = <value>, -- New flag value
        }
    }

#### `NODE QUERY` (advanced_npc:node_query)
Check and run a program with nodes found near.

    {
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
        
        on_found_executables = { --[[
            ^ Table where index is a itemstring of the node to be found, 
              and value is an array of programs to be performed 
              when found the node. ]]
       	
            ["itemstring1"] = {            
               [1] = <program>,
               [2] = <program>,
               [3] = <program>
            },
            ["itemstring2"] = {            
               [1] = <program>,
               [2] = <program>
            }
        },
        
        on_not_found_executables = { --[[ 
            ^ An array of programs to be performed when not found any node.
            
            [1] = <program>,
            [2] = <program>
        },
        
    }
