-- Basic utilities to work with table operations in Lua, and specific querying
-- By Zorman2000

npc.utils = {}

function npc.utils.split(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t={}
	local i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end

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
	for key, _ in pairs(map) do
		table.insert(result, key)
	end
	return result
end

function npc.utils.get_map_values(map)
	local result = {}
	for _, value in pairs(map) do
		table.insert(result, value)
	end
	return result
end

-- This function searches for a node given the conditions specified in the
-- query object, starting from the given start_pos and up to a certain, specified
-- range. 
-- Query object:
-- search_type: determines the direction to search nodes.
-- Valid values are: orthogonal, cross, cube
--   - orthogonal search means only nodes which are parallel to the search node's faces
--     will be considered. This limits the search to only 6 nodes.
--   - cross search will look at the same nodes as orthogonal, plus will also 
--     check nodes diagonal to the node four horizontal nodes. This search looks at 14 nodes
--   - cube search means to look every node surrounding the node, including all diagonals.
--     This search looks at 26 nodes. 
-- search_nodes: array of nodes to search for
-- surrounding_nodes: object specifying which neighbor nodes are to be expected and
-- at which locations. Valid keys are:
--   - North (+Z dir)
--   - East (+x dir)
--   - South (-Z dir)
--   - West (-X dir)
--   - Top (+Y dir)
--   - Bottom (-Y dir)
-- Example: ["bottom"] = {nodes={"default:dirt"}, criteria="all"}
-- Each object will contain nodes, and criteria for acceptance. 
-- Criteria values are:
--   - any: true as long as one of the nodes on this side is one of the specified 
--          in "nodes"
--   - all: true when the set of neighboring nodes on this side contain one or many of
--          the specified "nodes"
--   - all-exact: true when the set of neighboring nodes on this side contain all nodes
--		 		  specified in "nodes"
--   - shape: true when the set of neighboring nodes on this side contains nodes in
--            the exact given shape. If so, nodes will not be an array, but a 2d array
--            of three rows and three columns, with the specific shape. Notice that
--            the nodes on the side can vary depending on the search type (orthogonal,
--            cross, cube)
function npc.utils.search_node(query, start_pos, range)
	
end