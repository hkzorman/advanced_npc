advanced_npc
============

Introduction
------------

Advanced NPC is a mod for Minetest, based on mobs_redo.
The goal of this mod is to be able to have live villages in Minetest. These NPCs are highly inspired by the typical NPCs of Harvest Moon games. The general idea is that on almost all buildings of a village there are NPCs that are kind of intelligent: they have daily tasks they perform, can speak to players, can trade with the player, can use their own items (chests and furnaces for example), know where to go around their house and village, can be lumbers, miners or any other Minetest-suitable profession and can ultimately engage into relationships with the player. And while basically only players are mentioned here, the ultimate goal is that they can do all of this also among themselves, so that villages are alive and evolving by themselves, without player intervention.


Installation
------------

__NOTE__: Advanced NPC is still under development. While the mod is largely stable, it lacks one of the most important pieces: spawning. Currently, NPCs will spawn on stone (default:stone) and the mg_villages' plotmarkers (mg_villages:plotmarker). The spawning is not controlled, so you will have several of them walking around. This is not how it is planned and is just for testing purposes. In the future, only a handful of NPCs should spawn at village house's plotmarker and they will know their way around the house and have specific jobs.

Download the mod [here](https://github.com/hkzorman/advanced_npc/archive/master.zip) (link always pointing to latest version)

For this mod to work correctly, you also need to install the [mobs_redo](https://github.com/tenplus1/mobs_redo) mod. After installation, make sure you enable it in your world.

License
-------

__advanced_npc__ is Copyright (C) 2016-2017 Hector Franqui (zorman2000), licensed under the GPLv3 license. See `license.txt` for details.

The `jumper.lua` file contains code based on the [Jumper library](https://github.com/Yonaba/Jumper), which is Copyright (c) 2012-2013 Roland Yonaba, licensed under MIT license. See `actions/jumper.lua` for details.


Roadmap
-------

See it on the [wiki](https://github.com/hkzorman/advanced_npc/wiki).
