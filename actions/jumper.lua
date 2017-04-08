---------------------------------------------------------------------------------------
-- This code is entirely based on Jumper library 1.8.1 by Roland Yonaba.
-- The modifications are only to make it work under Minetest's secure
-- environment. Therefore, the code in this file is under the MIT license
-- as the original Jumper library (please see copyright notice below). 
-- The original library code can be found here: 
-- https://github.com/Yonaba/Jumper/releases/tag/jumper-1.8.1-1

-- Modifications are by Hector Franqui (Zorman2000)

---------------------------------------------------------------------------------------
-- Copyright (c) 2012-2013 Roland Yonaba

-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:

-- The above copyright notice and this permission notice shall be included
-- in all copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------

-- Local variables declarations
local abs = math.abs
local sqrt = math.sqrt
local max = math.max
local floor = math.floor
local t_insert, t_remove = table.insert, table.remove
local huge = math.huge


---------------------------------------------------------------------------------------
-- Heuristics based on implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/core/heuristics.lua
---------------------------------------------------------------------------------------
local Heuristics = {
  	['MANHATTAN'] = function(nodeA, nodeB) 
			local dx = abs(nodeA._x - nodeB._x)
			local dy = abs(nodeA._y - nodeB._y)
			return (dx + dy) 
		end,
		['EUCLIDIAN'] = function(nodeA, nodeB)
			local dx = nodeA._x - nodeB._x
			local dy = nodeA._y - nodeB._y
			return sqrt(dx*dx+dy*dy) 
		end
}


---------------------------------------------------------------------------------------
-- Node class implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/core/node.lua
---------------------------------------------------------------------------------------
local Node = setmetatable({},
		{__call = function(self,...) 
			return Node:new(...) 
		end}
	)
  Node.__index = Node

  --- Inits a new `node`
  -- @class function
  -- @tparam int x the x-coordinate of the node on the collision map
  -- @tparam int y the y-coordinate of the node on the collision map
  -- @treturn node a new `node`
	-- @usage local node = Node(3,4)
  function Node:new(x,y)
    return setmetatable({_x = x, _y = y, _clearance = {}}, Node)
  end

  -- Enables the use of operator '<' to compare nodes.
  -- Will be used to sort a collection of nodes in a binary heap on the basis of their F-cost
  function Node.__lt(A,B) return (A._f < B._f) end

  --- Returns x-coordinate of a `node`
  -- @class function
  -- @treturn number the x-coordinate of the `node`
	-- @usage local x = node:getX()	
	function Node:getX() return self._x end
	
  --- Returns y-coordinate of a `node`
  -- @class function
  -- @treturn number the y-coordinate of the `node`	
	-- @usage local y = node:getY()		
	function Node:getY() return self._y end
	
  --- Returns x and y coordinates of a `node`
  -- @class function
  -- @treturn number the x-coordinate of the `node`
  -- @treturn number the y-coordinate of the `node`
	-- @usage local x, y = node:getPos()		
	function Node:getPos() return self._x, self._y end
	
  --- Returns the amount of true [clearance](http://aigamedev.com/open/tutorial/clearance-based-pathfinding/#TheTrueClearanceMetric) 
	-- for a given `node`
  -- @class function
  -- @tparam string|int|func walkable the value for walkable locations in the collision map array.
  -- @treturn int the clearance of the `node`
	-- @usage
	--  -- Assuming walkable was 0	
	-- local clearance = node:getClearance(0)		
	function Node:getClearance(walkable)
		return self._clearance[walkable]
	end
	
  --- Removes the clearance value for a given walkable.
  -- @class function
  -- @tparam string|int|func walkable the value for walkable locations in the collision map array.
	-- @treturn node self (the calling `node` itself, can be chained)
	-- @usage
	--  -- Assuming walkable is defined	
	-- node:removeClearance(walkable)	
	function Node:removeClearance(walkable)
		self._clearance[walkable] = nil
		return self
	end
	
	--- Clears temporary cached attributes of a `node`.
	-- Deletes the attributes cached within a given node after a pathfinding call.
	-- This function is internally used by the search algorithms, so you should not use it explicitely.
	-- @class function
	-- @treturn node self (the calling `node` itself, can be chained)
	-- @usage
	-- local thisNode = Node(1,2)
	-- thisNode:reset()
	function Node:reset()
		self._g, self._h, self._f = nil, nil, nil
		self._opened, self._closed, self._parent = nil, nil, nil
		return self
	end


---------------------------------------------------------------------------------------
-- Path class implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/core/path.lua
---------------------------------------------------------------------------------------
--- The `Path` class.<br/>
-- This class is callable.
-- Therefore, <em><code>Path(...)</code></em> acts as a shortcut to <em><code>Path:new(...)</code></em>.
-- @type Path
local Path = setmetatable({},
    {__call = function(self,...)
      return Path:new(...)
    end
  })

Path.__index = Path

--- Inits a new `path`.
-- @class function
-- @treturn path a `path`
-- @usage local p = Path()
function Path:new()
  return setmetatable({_nodes = {}}, Path)
end

--- Iterates on each single `node` along a `path`. At each step of iteration,
-- returns the `node` plus a count value. Aliased as @{Path:nodes}
-- @class function
-- @treturn node a `node`
-- @treturn int the count for the number of nodes
-- @see Path:nodes
-- @usage
-- for node, count in p:iter() do
--   ...
-- end
function Path:iter()
  local i,pathLen = 1,#self._nodes
  return function()
    if self._nodes[i] then
      i = i+1
      return self._nodes[i-1],i-1
    end
  end
end

--- Iterates on each single `node` along a `path`. At each step of iteration,
-- returns a `node` plus a count value. Alias for @{Path:iter}
-- @class function
-- @name Path:nodes
-- @treturn node a `node`
-- @treturn int the count for the number of nodes
-- @see Path:iter	
-- @usage
-- for node, count in p:nodes() do
--   ...
-- end	
Path.nodes = Path.iter

--- Evaluates the `path` length
-- @class function
-- @treturn number the `path` length
-- @usage local len = p:getLength()
function Path:getLength()
  local len = 0
  for i = 2,#self._nodes do
    len = len + Heuristic.EUCLIDIAN(self._nodes[i], self._nodes[i-1])
  end
  return len
end

--- Counts the number of steps.
-- Returns the number of waypoints (nodes) in the current path.
-- @class function
-- @tparam node node a node to be added to the path
-- @tparam[opt] int index the index at which the node will be inserted. If omitted, the node will be appended after the last node in the path.
-- @treturn path self (the calling `path` itself, can be chained)
-- @usage local nSteps = p:countSteps()
function Path:addNode(node, index)
	index = index or #self._nodes+1
	t_insert(self._nodes, index, node)
	return self
end


--- `Path` filling modifier. Interpolates between non contiguous nodes along a `path`
-- to build a fully continuous `path`. This maybe useful when using search algorithms such as Jump Point Search.
-- Does the opposite of @{Path:filter}
-- @class function
-- @treturn path self (the calling `path` itself, can be chained)	
-- @see Path:filter
-- @usage p:fill()
function Path:fill()
  local i = 2
  local xi,yi,dx,dy
  local N = #self._nodes
  local incrX, incrY
  while true do
    xi,yi = self._nodes[i]._x,self._nodes[i]._y
    dx,dy = xi-self._nodes[i-1]._x,yi-self._nodes[i-1]._y
    if (abs(dx) > 1 or abs(dy) > 1) then
      incrX = dx/max(abs(dx),1)
      incrY = dy/max(abs(dy),1)
      t_insert(self._nodes, i, self._grid:getNodeAt(self._nodes[i-1]._x + incrX, self._nodes[i-1]._y +incrY))
      N = N+1
    else i=i+1
    end
    if i>N then break end
  end
	return self
end

--- `Path` compression modifier. Given a `path`, eliminates useless nodes to return a lighter `path` 
-- consisting of straight moves. Does the opposite of @{Path:fill}
-- @class function
-- @treturn path self (the calling `path` itself, can be chained)	
-- @see Path:fill
-- @usage p:filter()
function Path:filter()
  local i = 2
  local xi,yi,dx,dy, olddx, olddy
  xi,yi = self._nodes[i]._x, self._nodes[i]._y
  dx, dy = xi - self._nodes[i-1]._x, yi-self._nodes[i-1]._y
  while true do
    olddx, olddy = dx, dy
    if self._nodes[i+1] then
      i = i+1
      xi, yi = self._nodes[i]._x, self._nodes[i]._y
      dx, dy = xi - self._nodes[i-1]._x, yi - self._nodes[i-1]._y
      if olddx == dx and olddy == dy then
        t_remove(self._nodes, i-1)
        i = i - 1
      end
    else break end
  end
	return self
end

--- Clones a `path`.
-- @class function
-- @treturn path a `path`
-- @usage local p = path:clone()	
function Path:clone()
	local p = Path:new()
	for node in self:nodes() do p:addNode(node) end
	return p
end

--- Checks if a `path` is equal to another. It also supports *filtered paths* (see @{Path:filter}).
-- @class function
-- @tparam path p2 a path
-- @treturn boolean a boolean
-- @usage print(myPath:isEqualTo(anotherPath))
function Path:isEqualTo(p2)
	local p1 = self:clone():filter()
	local p2 = p2:clone():filter()
	for node, count in p1:nodes() do
		if not p2._nodes[count] then return false end
		local n = p2._nodes[count]
		if n._x~=node._x or n._y~=node._y then return false end
	end	
	return true
end

--- Reverses a `path`.
-- @class function
-- @treturn path self (the calling `path` itself, can be chained)
-- @usage myPath:reverse()	
function Path:reverse()
	local _nodes = {}
	for i = #self._nodes,1,-1 do
		_nodes[#_nodes+1] = self._nodes[i]		
	end
	self._nodes = _nodes
	return self
end	

--- Appends a given `path` to self.
-- @class function
-- @tparam path p a path
-- @treturn path self (the calling `path` itself, can be chained)
-- @usage myPath:append(anotherPath)		
function Path:append(p)
	for node in p:nodes() do self:addNode(node)	end
	return self
end


---------------------------------------------------------------------------------------
-- Utils class based on implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/core/utils.lua
---------------------------------------------------------------------------------------
local Utils = {
	traceBackPath = function(finder, node, startNode)
    local path = Path:new()
    path._grid = finder._grid
    while true do
      if node._parent then
        t_insert(path._nodes,1,node)
        node = node._parent
      else
        t_insert(path._nodes,1,startNode)
        return path
      end
    end
  end,

	-- Lookup for value in a table
	indexOf = function(t,v)
		for i = 1,#t do
			if t[i] == v then return i end
		end
		return nil
	end,

	getArrayBounds = function(map)
    local min_x, max_x
    local min_y, max_y
      for y in pairs(map) do
        min_y = not min_y and y or (y<min_y and y or min_y)
        max_y = not max_y and y or (y>max_y and y or max_y)
        for x in pairs(map[y]) do
          min_x = not min_x and x or (x<min_x and x or min_x)
          max_x = not max_x and x or (x>max_x and x or max_x)
        end
      end
    return min_x,max_x,min_y,max_y
  end,

  -- Converts an array to a set of nodes
  arrayToNodes = function(map)
    local min_x, max_x
    local min_y, max_y
    local nodes = {}
      for y in pairs(map) do
        min_y = not min_y and y or (y<min_y and y or min_y)
        max_y = not max_y and y or (y>max_y and y or max_y)
        nodes[y] = {}
        for x in pairs(map[y]) do
          min_x = not min_x and x or (x<min_x and x or min_x)
          max_x = not max_x and x or (x>max_x and x or max_x)
          nodes[y][x] = Node:new(x,y)
        end
      end
    return nodes,
			 (min_x or 0), (max_x or 0),
			 (min_y or 0), (max_y or 0)
  end
}


---------------------------------------------------------------------------------------
-- Bheap class implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/core/bheap.lua
---------------------------------------------------------------------------------------
-- Default comparison function
local function f_min(a,b) return a < b end

-- Percolates up
local function percolate_up(heap, index)
	if index == 1 then return end
	local pIndex
	if index <= 1 then return end
	if index%2 == 0 then
		pIndex =  index/2
	else pIndex = (index-1)/2
	end
	if not heap._sort(heap._heap[pIndex], heap._heap[index]) then
		heap._heap[pIndex], heap._heap[index] = 
			heap._heap[index], heap._heap[pIndex]
		percolate_up(heap, pIndex)
	end
end

-- Percolates down
local function percolate_down(heap,index)
	local lfIndex,rtIndex,minIndex
	lfIndex = 2*index
	rtIndex = lfIndex + 1
	if rtIndex > heap._size then
		if lfIndex > heap._size then return
		else minIndex = lfIndex  end
	else
		if heap._sort(heap._heap[lfIndex],heap._heap[rtIndex]) then
			minIndex = lfIndex
		else
			minIndex = rtIndex
		end
	end
	if not heap._sort(heap._heap[index],heap._heap[minIndex]) then
		heap._heap[index],heap._heap[minIndex] = heap._heap[minIndex],heap._heap[index]
		percolate_down(heap,minIndex)
	end
end

-- Produces a new heap
local function newHeap(template,comp)
	return setmetatable({_heap = {},
		_sort = comp or f_min, _size = 0},
	template)
end


--- The `heap` class.<br/>
-- This class is callable.
-- _Therefore,_ <code>heap(...)</code> _is used to instantiate new heaps_.
-- @type heap
local heap = setmetatable({},
	{__call = function(self,...)
		return newHeap(self,...)
	end})
heap.__index = heap

--- Checks if a `heap` is empty
-- @class function
-- @treturn bool __true__ of no item is queued in the heap, __false__ otherwise
-- @usage
-- if myHeap:empty() then 
--   print('Heap is empty!')
-- end
function heap:empty()
	return (self._size==0)
end

--- Clears the `heap` (removes all items queued in the heap)
-- @class function
-- @treturn heap self (the calling `heap` itself, can be chained)
-- @usage myHeap:clear()
function heap:clear()
	self._heap = {}
	self._size = 0
	self._sort = self._sort or f_min
	return self
end

--- Adds a new item in the `heap`
-- @class function
-- @tparam value item a new value to be queued in the heap
-- @treturn heap self (the calling `heap` itself, can be chained)
-- @usage
-- myHeap:push(1)
-- -- or, with chaining
-- myHeap:push(1):push(2):push(4)
function heap:push(item)
	if item then
		self._size = self._size + 1
		self._heap[self._size] = item
		percolate_up(self, self._size)
	end
	return self
end

--- Pops from the `heap`.
-- Removes and returns the lowest cost item (with respect to the comparison function being used) from the `heap`.
-- @class function
-- @treturn value a value previously pushed into the heap
-- @usage
-- while not myHeap:empty() do 
--   local lowestValue = myHeap:pop()
--   ...
-- end
function heap:pop()
	local root
	if self._size > 0 then
		root = self._heap[1]
		self._heap[1] = self._heap[self._size]
		self._heap[self._size] = nil
		self._size = self._size-1
		if self._size>1 then
			percolate_down(self, 1)
		end
	end
	return root
end

--- Restores the `heap` property.
-- Reorders the `heap` with respect to the comparison function being used. 
-- When given argument __item__ (a value existing in the `heap`), will sort from that very item in the `heap`. 
-- Otherwise, the whole `heap` will be cheacked. 
-- @class function
-- @tparam[opt] value item the modified value
-- @treturn heap self (the calling `heap` itself, can be chained)
-- @usage myHeap:heapify() 
function heap:heapify(item)
	if self._size == 0 then return end
	if item then
		local i = Utils.indexOf(self._heap,item)
		if i then 
			percolate_down(self, i)
			percolate_up(self, i)
		end
		return
	end
	for i = floor(self._size/2),1,-1 do
		percolate_down(self,i)
	end
	return self
end


---------------------------------------------------------------------------------------
-- Grid class implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/grid.lua
---------------------------------------------------------------------------------------
local pairs = pairs
local assert = assert
local next = next
local setmetatable = setmetatable
local coroutine = coroutine

-- Offsets for straights moves
local straightOffsets = {
  {x = 1, y = 0} --[[W]], {x = -1, y =  0}, --[[E]]
  {x = 0, y = 1} --[[S]], {x =  0, y = -1}, --[[N]]
}

-- Offsets for diagonal moves
local diagonalOffsets = {
  {x = -1, y = -1} --[[NW]], {x = 1, y = -1}, --[[NE]]
  {x = -1, y =  1} --[[SW]], {x = 1, y =  1}, --[[SE]]
}

--- The `Grid` class.<br/>
-- This class is callable.
-- Therefore,_ <code>Grid(...)</code> _acts as a shortcut to_ <code>Grid:new(...)</code>.
-- @type Grid
Grid = setmetatable({},{
  __call = function(self,...)
    return self:new(...)
  end
})
Grid.__index = Grid

-- Specialized grids
local PreProcessGrid = setmetatable({},Grid)
local PostProcessGrid = setmetatable({},Grid)
PreProcessGrid.__index = PreProcessGrid
PostProcessGrid.__index = PostProcessGrid
PreProcessGrid.__call = function (self,x,y)
  return self:getNodeAt(x,y)
end
PostProcessGrid.__call = function (self,x,y,create)
  if create then return self:getNodeAt(x,y) end
  return self._nodes[y] and self._nodes[y][x]
end

--- Inits a new `grid`
-- @class function
-- @tparam table|string map A collision map - (2D array) with consecutive indices (starting at 0 or 1)
-- or a `string` with line-break chars (<code>\n</code> or <code>\r</code>) as row delimiters.
-- @tparam[opt] bool cacheNodeAtRuntime When __true__, returns an empty `grid` instance, so that
-- later on, indexing a non-cached `node` will cause it to be created and cache within the `grid` on purpose (i.e, when needed).
-- This is a __memory-safe__ option, in case your dealing with some tight memory constraints.
-- Defaults to __false__ when omitted.
-- @treturn grid a new `grid` instance
-- @usage
-- -- A simple 3x3 grid
-- local myGrid = Grid:new({{0,0,0},{0,0,0},{0,0,0}})
--
-- -- A memory-safe 3x3 grid
-- myGrid = Grid('000\n000\n000', true)
function Grid:new(map, cacheNodeAtRuntime)
	if type(map) == 'string' then
		map = Utils.strToMap(map)
	end
  if cacheNodeAtRuntime then
    return PostProcessGrid:new(map,walkable)
  end
  return PreProcessGrid:new(map,walkable)
end

--- Checks if `node` at [x,y] is __walkable__.
-- Will check if `node` at location [x,y] both *exists* on the collision map and *is walkable*
-- @class function
-- @tparam int x the x-location of the node
-- @tparam int y the y-location of the node
-- @tparam[opt] string|int|func walkable the value for walkable locations in the collision map array (see @{Grid:new}).
-- Defaults to __false__ when omitted.
-- If this parameter is a function, it should be prototyped as __f(value)__ and return a `boolean`:
-- __true__ when value matches a __walkable__ `node`, __false__ otherwise. If this parameter is not given
-- while location [x,y] __is valid__, this actual function returns __true__.
-- @tparam[optchain] int clearance the amount of clearance needed. Defaults to 1 (normal clearance) when not given.
-- @treturn bool __true__ if `node` exists and is __walkable__, __false__ otherwise
-- @usage
-- -- Always true
-- print(myGrid:isWalkableAt(2,3))
--
-- -- True if node at [2,3] collision map value is 0
-- print(myGrid:isWalkableAt(2,3,0))
--
-- -- True if node at [2,3] collision map value is 0 and has a clearance higher or equal to 2
-- print(myGrid:isWalkableAt(2,3,0,2))
--
function Grid:isWalkableAt(x, y, walkable, clearance)
  local nodeValue = self._map[y] and self._map[y][x]
  if nodeValue then
    if not walkable then return true end
  else
		return false
  end
	local hasEnoughClearance = not clearance and true or false
	if not hasEnoughClearance then
		if not self._isAnnotated[walkable] then return false end
		local node = self:getNodeAt(x,y)
		local nodeClearance = node:getClearance(walkable)
		hasEnoughClearance = (nodeClearance >= clearance)
	end
  if self._eval then
		return walkable(nodeValue) and hasEnoughClearance
	end
  return ((nodeValue == walkable) and hasEnoughClearance)
end

--- Returns the `grid` width.
-- @class function
-- @treturn int the `grid` width
-- @usage print(myGrid:getWidth())
function Grid:getWidth()
  return self._width
end

--- Returns the `grid` height.
-- @class function
-- @treturn int the `grid` height
-- @usage print(myGrid:getHeight())
function Grid:getHeight()
   return self._height
end

--- Returns the collision map.
-- @class function
-- @treturn map the collision map (see @{Grid:new})
-- @usage local map = myGrid:getMap()
function Grid:getMap()
  return self._map
end

--- Returns the set of nodes.
-- @class function
-- @treturn {{node,...},...} an array of nodes
-- @usage local nodes = myGrid:getNodes()
function Grid:getNodes()
  return self._nodes
end

--- Returns the `grid` bounds. Returned values corresponds to the upper-left
-- and lower-right coordinates (in tile units) of the actual `grid` instance.
-- @class function
-- @treturn int the upper-left corner x-coordinate
-- @treturn int the upper-left corner y-coordinate
-- @treturn int the lower-right corner x-coordinate
-- @treturn int the lower-right corner y-coordinate
-- @usage local left_x, left_y, right_x, right_y = myGrid:getBounds()
function Grid:getBounds()
	return self._min_x, self._min_y,self._max_x, self._max_y
end

--- Returns neighbours. The returned value is an array of __walkable__ nodes neighbouring a given `node`.
-- @class function
-- @tparam node node a given `node`
-- @tparam[opt] string|int|func walkable the value for walkable locations in the collision map array (see @{Grid:new}).
-- Defaults to __false__ when omitted.
-- @tparam[optchain] bool allowDiagonal when __true__, allows adjacent nodes are included (8-neighbours).
-- Defaults to __false__ when omitted.
-- @tparam[optchain] bool tunnel When __true__, allows the `pathfinder` to tunnel through walls when heading diagonally.
-- @tparam[optchain] int clearance When given, will prune for the neighbours set all nodes having a clearance value lower than the passed-in value
-- Defaults to __false__ when omitted.
-- @treturn {node,...} an array of nodes neighbouring a given node
-- @usage
-- local aNode = myGrid:getNodeAt(5,6)
-- local neighbours = myGrid:getNeighbours(aNode, 0, true)
function Grid:getNeighbours(node, walkable, allowDiagonal, tunnel, clearance)
	local neighbours = {}
  for i = 1,#straightOffsets do
    local n = self:getNodeAt(
      node._x + straightOffsets[i].x,
      node._y + straightOffsets[i].y
    )
    if n and self:isWalkableAt(n._x, n._y, walkable, clearance) then
      neighbours[#neighbours+1] = n
    end
  end

  if not allowDiagonal then return neighbours end

	tunnel = not not tunnel
  for i = 1,#diagonalOffsets do
    local n = self:getNodeAt(
      node._x + diagonalOffsets[i].x,
      node._y + diagonalOffsets[i].y
    )
    if n and self:isWalkableAt(n._x, n._y, walkable, clearance) then
			if tunnel then
				neighbours[#neighbours+1] = n
			else
				local skipThisNode = false
				local n1 = self:getNodeAt(node._x+diagonalOffsets[i].x, node._y)
				local n2 = self:getNodeAt(node._x, node._y+diagonalOffsets[i].y)
				if ((n1 and n2) and not self:isWalkableAt(n1._x, n1._y, walkable, clearance) and not self:isWalkableAt(n2._x, n2._y, walkable, clearance)) then
					skipThisNode = true
				end
				if not skipThisNode then neighbours[#neighbours+1] = n end
			end
    end
  end

  return neighbours
end

--- Grid iterator. Iterates on every single node
-- in the `grid`. Passing __lx, ly, ex, ey__ arguments will iterate
-- only on nodes inside the bounding-rectangle delimited by those given coordinates.
-- @class function
-- @tparam[opt] int lx the leftmost x-coordinate of the rectangle. Default to the `grid` leftmost x-coordinate (see @{Grid:getBounds}).
-- @tparam[optchain] int ly the topmost y-coordinate of the rectangle. Default to the `grid` topmost y-coordinate (see @{Grid:getBounds}).
-- @tparam[optchain] int ex the rightmost x-coordinate of the rectangle. Default to the `grid` rightmost x-coordinate (see @{Grid:getBounds}).
-- @tparam[optchain] int ey the bottom-most y-coordinate of the rectangle. Default to the `grid` bottom-most y-coordinate (see @{Grid:getBounds}).
-- @treturn node a `node` on the collision map, upon each iteration step
-- @treturn int the iteration count
-- @usage
-- for node, count in myGrid:iter() do
--   print(node:getX(), node:getY(), count)
-- end
function Grid:iter(lx,ly,ex,ey)
  local min_x = lx or self._min_x
  local min_y = ly or self._min_y
  local max_x = ex or self._max_x
  local max_y = ey or self._max_y

  local x, y
  y = min_y
  return function()
    x = not x and min_x or x+1
    if x > max_x then
      x = min_x
      y = y+1
    end
    if y > max_y then
      y = nil
    end
    return self._nodes[y] and self._nodes[y][x] or self:getNodeAt(x,y)
  end
end

--- Grid iterator. Iterates on each node along the outline (border) of a squared area
-- centered on the given node.
-- @tparam node node a given `node`
-- @tparam[opt] int radius the area radius (half-length). Defaults to __1__ when not given.
-- @treturn node a `node` at each iteration step
-- @usage
-- for node in myGrid:around(node, 2) do
--   ...
-- end
function Grid:around(node, radius)
	local x, y = node._x, node._y
	radius = radius or 1
	local _around = Utils.around()
	local _nodes = {}
	repeat
		local state, x, y = coroutine.resume(_around,x,y,radius)
		local nodeAt = state and self:getNodeAt(x, y)
		if nodeAt then _nodes[#_nodes+1] = nodeAt end
	until (not state)
	local _i = 0
	return function()
		_i = _i+1
		return _nodes[_i]
	end
end

--- Each transformation. Calls the given function on each `node` in the `grid`,
-- passing the `node` as the first argument to function __f__.
-- @class function
-- @tparam func f a function prototyped as __f(node,...)__
-- @tparam[opt] vararg ... args to be passed to function __f__
-- @treturn grid self (the calling `grid` itself, can be chained)
-- @usage
-- local function printNode(node)
--   print(node:getX(), node:getY())
-- end
-- myGrid:each(printNode)
function Grid:each(f,...)
  for node in self:iter() do f(node,...) end
	return self
end

--- Each (in range) transformation. Calls a function on each `node` in the range of a rectangle of cells,
-- passing the `node` as the first argument to function __f__.
-- @class function
-- @tparam int lx the leftmost x-coordinate coordinate of the rectangle
-- @tparam int ly the topmost y-coordinate of the rectangle
-- @tparam int ex the rightmost x-coordinate of the rectangle
-- @tparam int ey the bottom-most y-coordinate of the rectangle
-- @tparam func f a function prototyped as __f(node,...)__
-- @tparam[opt] vararg ... args to be passed to function __f__
-- @treturn grid self (the calling `grid` itself, can be chained)
-- @usage
-- local function printNode(node)
--   print(node:getX(), node:getY())
-- end
-- myGrid:eachRange(1,1,8,8,printNode)
function Grid:eachRange(lx,ly,ex,ey,f,...)
  for node in self:iter(lx,ly,ex,ey) do f(node,...) end
	return self
end

--- Map transformation.
-- Calls function __f(node,...)__ on each `node` in a given range, passing the `node` as the first arg to function __f__ and replaces
-- it with the returned value. Therefore, the function should return a `node`.
-- @class function
-- @tparam func f a function prototyped as __f(node,...)__
-- @tparam[opt] vararg ... args to be passed to function __f__
-- @treturn grid self (the calling `grid` itself, can be chained)
-- @usage
-- local function nothing(node)
--   return node
-- end
-- myGrid:imap(nothing)
function Grid:imap(f,...)
  for node in self:iter() do
    node = f(node,...)
  end
	return self
end

--- Map in range transformation.
-- Calls function __f(node,...)__ on each `node` in a rectangle range, passing the `node` as the first argument to the function and replaces
-- it with the returned value. Therefore, the function should return a `node`.
-- @class function
-- @tparam int lx the leftmost x-coordinate coordinate of the rectangle
-- @tparam int ly the topmost y-coordinate of the rectangle
-- @tparam int ex the rightmost x-coordinate of the rectangle
-- @tparam int ey the bottom-most y-coordinate of the rectangle
-- @tparam func f a function prototyped as __f(node,...)__
-- @tparam[opt] vararg ... args to be passed to function __f__
-- @treturn grid self (the calling `grid` itself, can be chained)
-- @usage
-- local function nothing(node)
--   return node
-- end
-- myGrid:imap(1,1,6,6,nothing)
function Grid:imapRange(lx,ly,ex,ey,f,...)
  for node in self:iter(lx,ly,ex,ey) do
    node = f(node,...)
  end
	return self
end

-- Specialized grids
-- Inits a preprocessed grid
function PreProcessGrid:new(map)
  local newGrid = {}
  newGrid._map = map
  newGrid._nodes, newGrid._min_x, newGrid._max_x, newGrid._min_y, newGrid._max_y = Utils.arrayToNodes(newGrid._map)
  newGrid._width = (newGrid._max_x-newGrid._min_x)+1
  newGrid._height = (newGrid._max_y-newGrid._min_y)+1
	newGrid._isAnnotated = {}
  return setmetatable(newGrid,PreProcessGrid)
end

-- Inits a postprocessed grid
function PostProcessGrid:new(map)
  local newGrid = {}
  newGrid._map = map
  newGrid._nodes = {}
  newGrid._min_x, newGrid._max_x, newGrid._min_y, newGrid._max_y = Utils.getArrayBounds(newGrid._map)
  newGrid._width = (newGrid._max_x-newGrid._min_x)+1
  newGrid._height = (newGrid._max_y-newGrid._min_y)+1
	newGrid._isAnnotated = {}		
  return setmetatable(newGrid,PostProcessGrid)
end

--- Returns the `node` at location [x,y].
-- @class function
-- @name Grid:getNodeAt
-- @tparam int x the x-coordinate coordinate
-- @tparam int y the y-coordinate coordinate
-- @treturn node a `node`
-- @usage local aNode = myGrid:getNodeAt(2,2)

-- Gets the node at location <x,y> on a preprocessed grid
function PreProcessGrid:getNodeAt(x,y)
  return self._nodes[y] and self._nodes[y][x] or nil
end

-- Gets the node at location <x,y> on a postprocessed grid
function PostProcessGrid:getNodeAt(x,y)
  if not x or not y then return end
  if Utils.outOfRange(x,self._min_x,self._max_x) then return end
  if Utils.outOfRange(y,self._min_y,self._max_y) then return end
  if not self._nodes[y] then self._nodes[y] = {} end
  if not self._nodes[y][x] then self._nodes[y][x] = Node:new(x,y) end
  return self._nodes[y][x]
end


---------------------------------------------------------------------------------------
-- A* algorithm based on implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/search/astar.lua
---------------------------------------------------------------------------------------
-- Internalization
local ipairs = ipairs

-- Updates G-cost
local function computeCost(node, neighbour, finder, clearance)
	local mCost = Heuristics.EUCLIDIAN(neighbour, node)
	if node._g + mCost < neighbour._g then
		neighbour._parent = node
		neighbour._g = node._g + mCost
	end
end

-- Updates vertex node-neighbour
local function updateVertex(finder, openList, node, neighbour, endNode, clearance, heuristic, overrideCostEval)
	local oldG = neighbour._g
	local cmpCost = overrideCostEval or computeCost
	cmpCost(node, neighbour, finder, clearance)
	if neighbour._g < oldG then
		local nClearance = neighbour._clearance[finder._walkable]
		local pushThisNode = clearance and nClearance and (nClearance >= clearance)
		if (clearance and pushThisNode) or (not clearance) then
			if neighbour._opened then neighbour._opened = false end				
			neighbour._h = heuristic(endNode, neighbour)
			neighbour._f = neighbour._g + neighbour._h
			openList:push(neighbour)
			neighbour._opened = true
		end
	end
end

-- Calculates a path.
-- Returns the path from location `<startX, startY>` to location `<endX, endY>`.
local function ASTAR(finder, startNode, endNode, clearance, toClear, overrideHeuristic, overrideCostEval)
	
	local heuristic = overrideHeuristic or finder._heuristic
	local openList = heap()
	startNode._g = 0
	startNode._h = heuristic(endNode, startNode)
	startNode._f = startNode._g + startNode._h
	openList:push(startNode)
	toClear[startNode] = true
	startNode._opened = true

	while not openList:empty() do
		local node = openList:pop()
		node._closed = true
		if node == endNode then return node end
		local neighbours = finder._grid:getNeighbours(node, finder._walkable, finder._allowDiagonal, finder._tunnel)
		for i = 1,#neighbours do
			local neighbour = neighbours[i]
			if not neighbour._closed then
				toClear[neighbour] = true
				if not neighbour._opened then
					neighbour._g = huge
					neighbour._parent = nil	
				end
				updateVertex(finder, openList, node, neighbour, endNode, clearance, heuristic, overrideCostEval)
			end	
		end	
	end
	
	return nil 
end


---------------------------------------------------------------------------------------
-- Pathfinder class based on implementation by Ronald Yonaba
-- Original code here: https://github.com/Yonaba/Jumper/jumper/pathfinder.lua
---------------------------------------------------------------------------------------
local Finders = {
  ['ASTAR'] = ASTAR
}

-- Internalization
local pairs = pairs
local assert = assert
local type = type

local setmetatable, getmetatable = setmetatable, getmetatable

-- Will keep track of all nodes expanded during the search
-- to easily reset their properties for the next pathfinding call
local toClear = {}

--- Search modes. Refers to the search modes. In ORTHOGONAL mode, 4-directions are only possible when moving,
-- including North, East, West, South. In DIAGONAL mode, 8-directions are possible when moving,
-- including North, East, West, South and adjacent directions.
--
-- <li>ORTHOGONAL</li>
-- <li>DIAGONAL</li>
-- @mode Modes
-- @see Pathfinder:getModes
local searchModes = {['DIAGONAL'] = true, ['ORTHOGONAL'] = true}

-- Performs a traceback from the goal node to the start node
-- Only happens when the path was found

--- The `Pathfinder` class.<br/>
-- This class is callable.
-- Therefore,_ <code>Pathfinder(...)</code> _acts as a shortcut to_ <code>Pathfinder:new(...)</code>.
-- @type Pathfinder
Pathfinder = setmetatable({},{
  __call = function(self,...)
    return self:new(...)
  end
})
Pathfinder.__index = Pathfinder

--- Inits a new `pathfinder`
-- @class function
-- @tparam grid grid a `grid`
-- @tparam[opt] string finderName the name of the `Finder` (search algorithm) to be used for search.
-- Defaults to `ASTAR` when not given (see @{Pathfinder:getFinders}).
-- @tparam[optchain] string|int|func walkable the value for __walkable__ nodes.
-- If this parameter is a function, it should be prototyped as __f(value)__, returning a boolean:
-- __true__ when value matches a __walkable__ `node`, __false__ otherwise.
-- @treturn pathfinder a new `pathfinder` instance
-- @usage
-- -- Example one
-- local finder = Pathfinder:new(myGrid, 'ASTAR', 0)
--
-- -- Example two
-- local function walkable(value)
--   return value > 0
-- end
-- local finder = Pathfinder(myGrid, 'JPS', walkable)
function Pathfinder:new(grid, finderName, walkable)
  local newPathfinder = {}
  setmetatable(newPathfinder, Pathfinder)
  newPathfinder:setGrid(grid)
  newPathfinder:setFinder(finderName)
  newPathfinder:setWalkable(walkable)
  newPathfinder:setMode('DIAGONAL')
  newPathfinder:setHeuristic('MANHATTAN')
  newPathfinder:setTunnelling(false)
  return newPathfinder
end

--- Evaluates [clearance](http://aigamedev.com/open/tutorial/clearance-based-pathfinding/#TheTrueClearanceMetric)
-- for the whole `grid`. It should be called only once, unless the collision map or the
-- __walkable__ attribute changes. The clearance values are calculated and cached within the grid nodes.
-- @class function
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage myFinder:annotateGrid()
function Pathfinder:annotateGrid()
	--assert(self._walkable, 'Finder must implement a walkable value')
	for x=self._grid._max_x,self._grid._min_x,-1 do
		for y=self._grid._max_y,self._grid._min_y,-1 do
			local node = self._grid:getNodeAt(x,y)
			if self._grid:isWalkableAt(x,y,self._walkable) then
				local nr = self._grid:getNodeAt(node._x+1, node._y)
				local nrd = self._grid:getNodeAt(node._x+1, node._y+1)
				local nd = self._grid:getNodeAt(node._x, node._y+1)
				if nr and nrd and nd then
					local m = nrd._clearance[self._walkable] or 0
					m = (nd._clearance[self._walkable] or 0)<m and (nd._clearance[self._walkable] or 0) or m
					m = (nr._clearance[self._walkable] or 0)<m and (nr._clearance[self._walkable] or 0) or m
					node._clearance[self._walkable] = m+1
				else
					node._clearance[self._walkable] = 1
				end
			else node._clearance[self._walkable] = 0
			end
		end
	end
	self._grid._isAnnotated[self._walkable] = true
	return self
end

--- Removes [clearance](http://aigamedev.com/open/tutorial/clearance-based-pathfinding/#TheTrueClearanceMetric)values.
-- Clears cached clearance values for the current __walkable__.
-- @class function
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage myFinder:clearAnnotations()
function Pathfinder:clearAnnotations()
	--assert(self._walkable, 'Finder must implement a walkable value')
	for node in self._grid:iter() do
		node:removeClearance(self._walkable)
	end
	self._grid._isAnnotated[self._walkable] = false
	return self
end

--- Sets the `grid`. Defines the given `grid` as the one on which the `pathfinder` will perform the search.
-- @class function
-- @tparam grid grid a `grid`
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage myFinder:setGrid(myGrid)
function Pathfinder:setGrid(grid)
  --assert(Assert.inherits(grid, Grid), 'Wrong argument #1. Expected a \'grid\' object')
  self._grid = grid
  self._grid._eval = self._walkable and type(self._walkable) == 'function'
  return self
end

--- Returns the `grid`. This is a reference to the actual `grid` used by the `pathfinder`.
-- @class function
-- @treturn grid the `grid`
-- @usage local myGrid = myFinder:getGrid()
function Pathfinder:getGrid()
  return self._grid
end

--- Sets the __walkable__ value or function.
-- @class function
-- @tparam string|int|func walkable the value for walkable nodes.
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage
-- -- Value '0' is walkable
-- myFinder:setWalkable(0)
--
-- -- Any value greater than 0 is walkable
-- myFinder:setWalkable(function(n)
--   return n>0
-- end
function Pathfinder:setWalkable(walkable)
  --assert(Assert.matchType(walkable,'stringintfunctionnil'),
  --  ('Wrong argument #1. Expected \'string\', \'number\' or \'function\', got %s.'):format(type(walkable)))
  self._walkable = walkable
  self._grid._eval = type(self._walkable) == 'function'
  return self
end

--- Gets the __walkable__ value or function.
-- @class function
-- @treturn string|int|func the `walkable` value or function
-- @usage local walkable = myFinder:getWalkable()
function Pathfinder:getWalkable()
  return self._walkable
end

--- Defines the `finder`. It refers to the search algorithm used by the `pathfinder`.
-- Default finder is `ASTAR`. Use @{Pathfinder:getFinders} to get the list of available finders.
-- @class function
-- @tparam string finderName the name of the `finder` to be used for further searches.
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage
-- --To use Breadth-First-Search
-- myFinder:setFinder('BFS')
-- @see Pathfinder:getFinders
function Pathfinder:setFinder(finderName)
	if not finderName then
		if not self._finder then
			finderName = 'ASTAR'
		else return
		end
	end
  --assert(Finders[finderName],'Not a valid finder name!')
  self._finder = finderName
  return self
end

--- Returns the name of the `finder` being used.
-- @class function
-- @treturn string the name of the `finder` to be used for further searches.
-- @usage local finderName = myFinder:getFinder()
function Pathfinder:getFinder()
  return self._finder
end

--- Returns the list of all available finders names.
-- @class function
-- @treturn {string,...} array of built-in finders names.
-- @usage
-- local finders = myFinder:getFinders()
-- for i, finderName in ipairs(finders) do
--   print(i, finderName)
-- end
function Pathfinder:getFinders()
  return Utils.getKeys(Finders)
end

--- Sets a heuristic. This is a function internally used by the `pathfinder` to find the optimal path during a search.
-- Use @{Pathfinder:getHeuristics} to get the list of all available `heuristics`. One can also define
-- his own `heuristic` function.
-- @class function
-- @tparam func|string heuristic `heuristic` function, prototyped as __f(dx,dy)__ or as a `string`.
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @see Pathfinder:getHeuristics
-- @see core.heuristics
-- @usage myFinder:setHeuristic('MANHATTAN')
function Pathfinder:setHeuristic(heuristic)
  --assert(Heuristic[heuristic] or (type(heuristic) == 'function'),'Not a valid heuristic!')
  self._heuristic = Heuristics[heuristic] or heuristic
  return self
end

--- Returns the `heuristic` used. Returns the function itself.
-- @class function
-- @treturn func the `heuristic` function being used by the `pathfinder`
-- @see core.heuristics
-- @usage local h = myFinder:getHeuristic()
function Pathfinder:getHeuristic()
  return self._heuristic
end

--- Gets the list of all available `heuristics`.
-- @class function
-- @treturn {string,...} array of heuristic names.
-- @see core.heuristics
-- @usage
-- local heur = myFinder:getHeuristic()
-- for i, heuristicName in ipairs(heur) do
--   ...
-- end
function Pathfinder:getHeuristics()
  return Utils.getKeys(Heuristic)
end

--- Defines the search `mode`.
-- The default search mode is the `DIAGONAL` mode, which implies 8-possible directions when moving (north, south, east, west and diagonals).
-- In `ORTHOGONAL` mode, only 4-directions are allowed (north, south, east and west).
-- Use @{Pathfinder:getModes} to get the list of all available search modes.
-- @class function
-- @tparam string mode the new search `mode`.
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @see Pathfinder:getModes
-- @see Modes
-- @usage myFinder:setMode('ORTHOGONAL')
function Pathfinder:setMode(mode)
  --assert(searchModes[mode],'Invalid mode')
  self._allowDiagonal = (mode == 'DIAGONAL')
  return self
end

--- Returns the search mode.
-- @class function
-- @treturn string the current search mode
-- @see Modes
-- @usage local mode = myFinder:getMode()
function Pathfinder:getMode()
  return (self._allowDiagonal and 'DIAGONAL' or 'ORTHOGONAL')
end

--- Gets the list of all available search modes.
-- @class function
-- @treturn {string,...} array of search modes.
-- @see Modes
-- @usage local modes = myFinder:getModes()
-- for modeName in ipairs(modes) do
--   ...
-- end
function Pathfinder:getModes()
  return Utils.getKeys(searchModes)
end

--- Enables tunnelling. Defines the ability for the `pathfinder` to tunnel through walls when heading diagonally.
-- This feature __is not compatible__ with Jump Point Search algorithm (i.e. enabling it will not affect Jump Point Search)
-- @class function
-- @tparam bool bool a boolean
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage myFinder:setTunnelling(true)
function Pathfinder:setTunnelling(bool)
  --assert(Assert.isBool(bool), ('Wrong argument #1. Expected boolean, got %s'):format(type(bool)))
	self._tunnel = bool
	return self
end

--- Returns tunnelling feature state.
-- @class function
-- @treturn bool tunnelling feature actual state
-- @usage local isTunnellingEnabled = myFinder:getTunnelling()
function Pathfinder:getTunnelling()
	return self._tunnel
end

--- Calculates a `path`. Returns the `path` from location __[startX, startY]__ to location __[endX, endY]__.
-- Both locations must exist on the collision map. The starting location can be unwalkable.
-- @class function
-- @tparam int startX the x-coordinate for the starting location
-- @tparam int startY the y-coordinate for the starting location
-- @tparam int endX the x-coordinate for the goal location
-- @tparam int endY the y-coordinate for the goal location
-- @tparam int clearance the amount of clearance (i.e the pathing agent size) to consider
-- @treturn path a path (array of nodes) when found, otherwise nil
-- @usage local path = myFinder:getPath(1,1,5,5)
function Pathfinder:getPath(startX, startY, endX, endY, clearance)
	self:reset()
  local startNode = self._grid:getNodeAt(startX, startY)
  local endNode = self._grid:getNodeAt(endX, endY)
  --assert(startNode, ('Invalid location [%d, %d]'):format(startX, startY))
  --assert(endNode and self._grid:isWalkableAt(endX, endY),
  --  ('Invalid or unreachable location [%d, %d]'):format(endX, endY))
  local _endNode = Finders[self._finder](self, startNode, endNode, clearance, toClear)
  if _endNode then
		return Utils.traceBackPath(self, _endNode, startNode)
  end
  return nil
end

--- Resets the `pathfinder`. This function is called internally between successive pathfinding calls, so you should not
-- use it explicitely, unless under specific circumstances.
-- @class function
-- @treturn pathfinder self (the calling `pathfinder` itself, can be chained)
-- @usage local path, len = myFinder:getPath(1,1,5,5)
function Pathfinder:reset()
  for node in pairs(toClear) do node:reset() end
  toClear = {}
	return self
end


-- Returns Pathfinder class
Pathfinder._VERSION = _VERSION
Pathfinder._RELEASEDATE = _RELEASEDATE
