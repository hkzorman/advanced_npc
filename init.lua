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
dofile(path .. "/actions/actions.lua")
dofile(path .. "/actions/places.lua")
dofile(path .. "/actions/pathfinder.lua")
dofile(path .. "/actions/node_registry.lua")
dofile(path .. "/occupations/occupations.lua")
-- Load random data definitions
dofile(path .. "/random_data.lua")
dofile(path .. "/data/dialogues_data.lua")
dofile(path .. "/data/gift_items_data.lua")
dofile(path .. "/data/names_data.lua")
dofile(path .. "/data/occupations/default.lua")
dofile(path .. "/data/occupations/default_farmer.lua")
dofile(path .. "/data/occupations/default_priest.lua")

print (S("[Mod] Advanced NPC loaded"))
