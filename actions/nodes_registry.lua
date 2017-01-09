-- Node functionality for actions by Zorman2000
-- In this script, some functionality and information required for nodes
-- to be used correctly by an NPC is described.

-- Attempt to keep a register of how to use some nodes
npc.actions.nodes = {
  doors = {},
  beds = {},
  sittable = {}
}

-- Register default beds. Always register bottom node only
npc.actions.nodes.beds["beds:bed_bottom"] = {
  get_lay_pos = function(pos)
    return {x = pos.x + dir.x / 2, y = pos.y + 1, z = pos.z + dir.z / 2}
  end
}

npc.actions.nodes.beds["beds:fancy_bed_bottom"] = {
  get_lay_pos = function(pos)
    return {x = pos.x + dir.x / 2, y = pos.y + 1, z = pos.z + dir.z / 2}
  end
}

npc.actions.nodes.beds[""]