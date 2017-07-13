-- Basic utilities to work with array operations in Lua
-- By Zorman2000

npc.utils = {}

function npc.utils.array_contains(array, item)
	--minetest.log("Array: "..dump(array))
	--minetest.log("Item being searched: "..dump(item))
	for i = 1, #array do
		--minetest.log("Equals? "..dump(array[i] == item))
		if array[i] == item then
			return true
		end
	end
	return false
end

function npc.utils.array_is_subset_of_array(set, subset)
	local match_count = 0
	for j = 1, #subset do
		for k = 1, #set do
			if subset[j] == set[k] then
				match_count = match_count + 1
			end
		end
	end
	-- Check match count
	return match_count == #subset
end

function npc.utils.get_map_keys(map)
	local result = {}
	for key, value in pairs(map) do
		table.insert(result, key)
	end
	return result
end