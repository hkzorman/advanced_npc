Actions and Tasks
Advanced_NPC Alpha-2 (DEV)
==========================

IMPORTANT: In this documentation is only the explanation of the particular operation of each predefined 
action and task. Read reference documentation for details about API operation at [api.md](api.md).

Action (`add_action`)
---------------------

#### `SET_INTERVAL` 
Set the interval at which the `action` are executed.

    {
        interval = 1, -- A decimal number, in seconds (default is 1 second)
        freeze = false, -- if true, mobs_redo API will not execute until interval is set
    }

#### `FREEZE` 
This action allows to stop/execute mobs_redo API. 
This is good for stopping the NPC from fighting, wandering, etc.
  
    {
        freeze = false, -- Boolean, if true, mobs_redo API will not execute.
    }

Tasks (`add_task`)
------------------

#### `USE_BED` 
Sequence of actions that allows the NPC to use a bed.

    {
        pos = {x=0,y=0,z=0}, --[[
            ^ Position of bed to be used.
            ^ Can be a coordinate x,y,z.
            ^ Can be a place name of the NPC place map.
              Example: "bed_primary" ]]
        
        action = action, --[[ 
            ^ Whether to get up or lay on bed
            ^ Defined in npc.actions.const.beds.action
            ^ Available options:
              * npc.actions.const.beds.LAY : lay
              * npc.actions.const.beds.GET_UP : get up
    }

#### `WALK_TO_POS`
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
