# advanced_npc
Advanced NPC framework for Minetest, based on mobs_redo.
The goal of this mod is to be able to have live villages in Minetest. These NPCs are highly inspired by the typical NPCs of Harvest Moon games. The general idea is that on almost all buildings of a village there are NPCs that are kind of intelligent: they have daily tasks they perform, can speak to players, can trade with the player, can use their own items (chests for example), know where to go around their village, can be lumbers, miners or any other Minetest-suitable profession and can ultimately engage into relationships with the player. And while basically only players are mentioned here, the ultimate goal is that they can do all of this also among themselves, so that villages are completely alive and evolving by themselves, without necessary player intervention.

----------

Current roadmap:

Version 1.0
-----------
Phase 1: Gifts and relationships: In progress
- NPCs should be able to receive items
- NPCs will have favorite and disliked items
- Giving an NPC their favorite or disliked item will affect positively/negatively their
  relationship with that player.
- Eventually, an NPC can fall in love with that player and marry him/her
- Relationships among NPCs should be possible too

Phase 2: Dialogues: Completed
- NPCs should be able to perform complex dialogues:
  - Use yes/no or multiple option dialogue boxes to interact with player
  - Answers and responses by player
  TODO: Specific dialogues on certain environment flag (so that events can change what an NPC says

Phase 3: Trading
- NPCs should be able to trade, either buy or sell items to/from player and other NPCs
- Goal is to implement trading with player first

Phase 4: Owning nodes, being able to go to places
- NPCs should be able to own chests, furnaces and doors and use them
- NPCs should be able to go to specific places in their own homes or villages or in the world in general:
  - For this, a places framework should be defined
  - NPCs at least should know where their bed is, and use it
  
Phase 5: Activities and jobs
  - NPCs should be able to dig and place nodes
  - NPCs should be able to perform different activities on different times of the day
  
Phase 6: Advanced spawners for villages

Version 2.0
-----------
Phase 7: Make NPCs scriptable

Phase 8: Improve NPCs so that they can be farmers, lumberjacks and miners

Phase 9: Improve NPCs so that they can tame and own farm animals

Phase 10: Improve NPCs so that they can run on carts, boats and (maybe) horses

Version 3.0
-----------
Phase 11: Integrate with commerce mod

Phase 12: Improve relationships for obtaining more benefits from a married NPC

Phase 13: Improve AI to include support for house families

Phase 14: Improve AI to create village communities


License for Code
----------------

Copyright (C) 2016 Zorman2000

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
