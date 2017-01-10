-- Node functionality registry for NPC actions by Zorman2000
---------------------------------------------------------------------------------------
-- In this script, some functionality and information required for nodes
-- to be used correctly by an NPC is described.
-- To avoid as many definitions as possible, the names of the nodes
-- can actually be prefixes.

-- This table will contain the registered nodes
npc.actions.nodes = {
  doors = {},
  beds = {},
  sittable = {}
}


---------------------------------------------------------------------------------------
-- Beds functionality supported by default
---------------------------------------------------------------------------------------
-- Functionality for default beds. Since other mods may be used in the 
-- same way as the default beds, this one is a global registration
npc.actions.nodes.default_bed_registration = {
  get_lay_pos = function(pos, dir)
    return {x = pos.x + dir.x / 2, y = pos.y + 1, z = pos.z + dir.z / 2}
  end,
  type = "bed"
}

-- The code used in get_lay_pos is from cottages mod and slightly modified.
local cottages_bed_registration = {
  get_lay_pos = function(pos, dir)
    return {x = pos.x + dir.x / 2, y = pos.y + 1.4, z = pos.z + dir.z / 2}
  end,
  type = "bed"
}

local cottages_mat_registration = {
  get_lay_pos = function(pos, dir)
    return {x = pos.x + dir.x / 2, y = pos.y + 1, z = pos.z + dir.z / 2}
  end,
  type = "mat"
}

---------------------------------------------------------------------------------------
-- Beds
---------------------------------------------------------------------------------------
-- Default beds.
npc.actions.nodes.beds["beds:bed_bottom"] = npc.actions.nodes.default_bed_registration
npc.actions.nodes.beds["beds:fancy_bed_bottom"] = npc.actions.nodes.default_bed_registration

-- Cottages beds
npc.actions.nodes.beds["cottages:bed_foot"] = cottages_bed_registration
npc.actions.nodes.beds["cottages:sleeping_mat"] = cottages_mat_registration
npc.actions.nodes.beds["cottages:straw_mat"] = cottages_mat_registration
