advanced_npc
============

Introduction
------------

Advanced NPC framework for Minetest, based on mobs_redo.
The goal of this mod is to be able to have live villages in Minetest. These NPCs are highly inspired by the typical NPCs of Harvest Moon games. The general idea is that on almost all buildings of a village there are NPCs that are kind of intelligent: they have daily tasks they perform, can speak to players, can trade with the player, can use their own items (chests for example), know where to go around their village, can be lumbers, miners or any other Minetest-suitable profession and can ultimately engage into relationships with the player. And while basically only players are mentioned here, the ultimate goal is that they can do all of this also among themselves, so that villages are completely alive and evolving by themselves, without necessary player intervention.


License
-------

__advanced_npc__ is Copyright (C) 2016-2017 Hector Franqui (zorman2000), licensed under the GPLv3 license. See `license.txt` for details.

The Jumper library is Copyright (c) 2012-2013 Roland Yonaba, licensed under MIT license. See `Jumper/LICENSE.txt` for details.


Current progress and roadmap
----------------------------

__Version 1.0__

__Phase 1__: Gifts and relationships: In progress
- [x] NPCs should be able to receive items
- [x] NPCs will have favorite and disliked items
- [x] Giving an NPC their favorite or disliked item will affect positively/negatively their
  relationship with that player.
- [x] Eventually, an NPC can fall in love with that player and marry him/her
- [ ] Relationships among NPCs should be possible too

__Phase 2__: Dialogues: In progress
- [ ] NPCs should be able to perform complex dialogues:
  - [x] Use yes/no or multiple option dialogue boxes to interact with player
  - [x] Answers and responses by player
  - [ ] Specific dialogues on certain flags (so that events can change what an NPC says)

__Phase 3__: Trading: In progress
- [ ] NPCs should be able to trade, either buy or sell items to/from player and other NPCs
  - There are two types of traders: casual and dedicated.
    - [x] Casual traders are normal NPC which occasionaly make buy or sell offers to the player
    - [ ] Dedicated traders are traders that, when talked to, always make buy and sell offers. They have a greater variety too.
- [ ] NPCs will also be able to offer "services", for example, repairing tools, by receiving an item and a payment, and then returning a specific item.

__Phase 4__: Actions: In progress
- [ ] NPCs should be able to use chests, furnaces, doors, beds and sit on "sittable" nodes (in progress)
- [x] NPCs should be able to walk to specific places. Should also be able to open doors, fence gates and any other type of openable node while going to a place.
- [x] NPCs should have the ability to identify nodes that belong to him/her, and recall them/
  
__Phase 5__: Schedules and fundamental jobs
  - [ ] NPCs should be able to perform different activities on depending on the time of the day. For instance, a NPC could be farming during the morning, selling its product on the afternoon, and comfortable sitting at home during the night.
  - [ ] Add the fundamental jobs, which are:
  	- [ ] Mining
  	- [ ] Wood cutting
  	- [ ] Farming
  	- [ ] Cooking
  
__Phase 6__: Advanced spawners for villages
  - [ ] Support for mg_villages mod by Sokomine
    - [ ] Identify, on medieval villages, houses that NPC can live on.
    - [ ] Identify the amount of NPC that the house can support
    - [ ] Spawn NPCs and assign them a bed. Detect sharable objects (chest, furnace, benches)
    - [ ] Assign them random schedules based on the type of building they spawn.


__Version 2.0__

Phase 7: Make NPCs scriptable

Phase 8: Improve NPCs pathfinding, allow them to go upstairs.

Phase 9: Improve NPCs so that they can tame and own farm animals

Phase 10: Improve NPCs so that they can run on carts, boats and (maybe) horses

__Version 3.0__

Phase 11: Integrate with commerce mod

Phase 12: Improve relationships for obtaining more benefits from a married NPC

Phase 13: Improve AI to include support for house families

Phase 14: Improve AI to create village communities