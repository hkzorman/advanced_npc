-- Advanced NPC mod by Zorman2000
local path = minetest.get_modpath("advanced_npc")

-- Intllib
local S
if minetest.get_modpath("intllib") then
	S = intllib.Getter()
else
	S = function(s, a, ...)
		if a == nil then
			return s
		end
		a = {a, ...}
		return s:gsub("(@?)@(%(?)(%d+)(%)?)",
			function(e, o, n, c)
				if e == ""then
					return a[tonumber(n)] .. (o == "" and c or "")
				else
					return "@" .. o .. n .. c
				end
			end)
	end
end
mobs.intllib = S

dofile(path .. "/npc.lua")
dofile(path .. "/utils.lua")
dofile(path .. "/spawner.lua")
dofile(path .. "/relationships.lua")
dofile(path .. "/dialogue.lua")
dofile(path .. "/trade/trade.lua")
dofile(path .. "/trade/prices.lua")
--dofile(path .. "/actions/actions.lua")
-- New program/instructions API
dofile(path .. "/executable/programs/api.lua")
dofile(path .. "/executable/helper.lua")
dofile(path .. "/executable/instructions/api.lua")
dofile(path .. "/executable/instructions/builtin_instructions.lua")
-- Builtin programs
dofile(path .. "/executable/programs/builtin/follow.lua")
dofile(path .. "/executable/programs/builtin/idle.lua")
dofile(path .. "/executable/programs/builtin/wander.lua")
dofile(path .. "/executable/programs/builtin/walk_to_pos.lua")
dofile(path .. "/executable/programs/builtin/use_bed.lua")
dofile(path .. "/executable/programs/builtin/use_sittable.lua")
dofile(path .. "/executable/programs/builtin/internal_property_change.lua")
dofile(path .. "/executable/programs/builtin/node_query.lua")
dofile(path .. "/executable/locations.lua")
dofile(path .. "/executable/pathfinder.lua")
dofile(path .. "/executable/node_registry.lua")
dofile(path .. "/occupations/occupations.lua")
-- Load random data definitions
dofile(path .. "/info/info.lua")
--dofile(path .. "/random_data.lua")
--dofile(path .. "/data/dialogues_data.lua")
--dofile(path .. "/data/gift_items_data.lua")
--dofile(path .. "/data/names_data.lua")
--dofile(path .. "/data/occupations/default.lua")
--dofile(path .. "/data/occupations/default_farmer.lua")
--dofile(path .. "/data/occupations/default_priest.lua")
--dofile(path .. "/data/occupations/default_miner.lua")

print (S("[Mod] Advanced NPC loaded"))
