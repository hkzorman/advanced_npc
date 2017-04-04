-- Advanced NPC mod by Zorman2000
local path = minetest.get_modpath("advanced_npc")

-- Below code for require is taken and slightly modified
-- from irc mod by Diego Martinez (kaeza)
-- https://github.com/minetest-mods/irc
-- Handle mod security if needed
-- local ie = minetest.request_insecure_environment()
-- -- local req_ie = minetest.request_insecure_environment()
-- -- if req_ie then 
-- --   ie = req_ie 
-- -- end
-- if not ie then
--   error("The Advanced NPC mod requires access to insecure functions in "..
--     "order to work.  Please add the Advanced NPC mod to the "..
--     "secure.trusted_mods setting or disable the mod.")
-- end

-- -- Modify package path so that it can find the Jumper library files
-- ie.package.path = 
--   path .. "/Jumper/?.lua;"..
--   ie.package.path

-- -- Require the main files from Jumper
-- Grid = ie.require("jumper.grid")
-- Pathfinder = ie.require("jumper.pathfinder")

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

-- NPC
dofile(path .. "/npc.lua")
dofile(path .. "/spawner.lua")
dofile(path .. "/relationships.lua")
dofile(path .. "/dialogue.lua")
dofile(path .. "/trade/trade.lua")
dofile(path .. "/trade/prices.lua")
dofile(path .. "/actions/actions.lua")
dofile(path .. "/actions/places.lua")
dofile(path .. "/actions/pathfinder.lua")
dofile(path .. "/actions/jumper.lua")
dofile(path .. "/actions/node_registry.lua")
dofile(path .. "/random_data.lua")

print (S("[Mod] Advanced NPC loaded"))
