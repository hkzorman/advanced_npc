Instructions for Programs
Advanced_NPC Alpha-2 (DEV)
==========================

IMPORTANT: In this documentation is only the explanation of the particular 
operation of each predefined instructions. Read reference documentation 
for details about API operation at [api.md](api.md).

### Default Instructions
These instructions are already registered in the API.
This section describes these instructions and their respective arguments.

#### `WAIT` (advanced_npc:wait)
This instruction causes the object to wait stopped for a time.
In other words, syntacic sugar to make a process wait for a specific interval.

    {
        time = <number>, -- Time number in seconds
    }
