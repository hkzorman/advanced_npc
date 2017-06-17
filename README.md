advanced_npc
============

Introduction
------------

Advanced NPC is a mod for Minetest using mobs_redo API.
The goal of this mod is to be able to have live villages in Minetest. These NPCs are highly inspired by the typical NPCs of _Harvest Moon_ games. The general idea is that on almost all buildings of a village there are NPCs that are kind of intelligent: they have daily tasks they perform, can speak to players, can trade with the player, can use their own items (chests and furnaces for example), know where to go around their house and village, can be lumbers, miners or any other Minetest-suitable profession and can ultimately engage into relationships with the player. And while basically only players are mentioned here, the ultimate goal is that they can do all of this also among themselves, so that villages are alive and evolving by themselves, without player intervention.


Installation
------------

__NOTE__: Advanced NPC is still under development. While the mod is largely stable, it lacks one of the most important pieces: spawning. Currently, NPCs can be spawned using eggs (found in creative inventory as 'NPC') and by themselves on villages of the [mg_villages mod](https://forum.minetest.net/viewtopic.php?t=13589). NPCs will spawn automatically on mg_villages villages and over time will populate the entire village. If something goes wrong, you can reset the village by:
  - Clearing all objects (in chat, type /clearobjects quick)
  - Restore original plotmarkers (in chat, type /restore_plotmarkers radius)
    - The radius can be any number, but it is recommended you use a not so large number. 200 is suitable. So stand in the middle of the village and then run that command.
This will actually restore the village and will slowly make NPCs spawn again. Currently there's no way to disable NPCs spawning on village, except by going to `spawner.lua` and commenting out all of `minetest.register_abm()` code.

__Download__ the mod [here](https://github.com/hkzorman/advanced_npc/archive/master.zip) (link always pointing to latest version)

For this mod to work correctly, you also need to install the [mobs_redo](https://github.com/tenplus1/mobs_redo) mod. After installation, make sure you enable it in your world.


License
-------

__advanced_npc__ is Copyright (C) 2016-2017 Hector Franqui (zorman2000), licensed under the GPLv3 license. See `license.txt` for details.

The `pathfinder.lua` file contains code slighlty modified from the [pathfinder mod](https://github.com/MarkuBu/pathfinder) by MarkBu, which is licensed as WTFPL. See `actions/pathfinder.lua` for details.

Current NPC textures are from mobs_redo mod.
The following textures are by Zorman2000:
- marriage_ring.png - CC BY-SA


Documentation and API
---------------------

This mod requires a good user manual, and also is planned to have an extensive API, properly documented. Unfortunately, these still aren't ready. A very very very WIP manual can be found in the [wiki](https://github.com/hkzorman/advanced_npc/wiki/Concept%3A-Dialogues)


Roadmap
-------

See it on the [wiki](https://github.com/hkzorman/advanced_npc/wiki).
