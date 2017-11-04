Actions and Tasks
Advanced_NPC Alpha-2 (DEV)
==========================

IMPORTANT: In this documentation is only the explanation of the particular operation of each predefined 
action and task. Read reference documentation for details about API operation at [api.md](api.md).

Action (`add_action`)
---------------------

Definition tables
-----------------

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
        pos = {x=0,y=0,z=0}, -- Position of bed to be used.
        action = action, --[[ 
            ^ Whether to get up or lay on bed
            ^ Defined in npc.actions.const.beds.action
            ^ Example: npc.actions.const.beds.action.LAY ]]
    }
