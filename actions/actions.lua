-- Actions code for Advanced NPC by Zorman2000
---------------------------------------------------------------------------------------
-- Action functionality
---------------------------------------------------------------------------------------
-- The NPCs will be able to perform five fundamental actions that will allow
-- for them to perform any other kind of interaction in the world. These
-- fundamental actions are: place a node, dig a node, put items on an inventory,
-- take items from an inventory, find a node closeby (radius 3) and
-- walk a step on specific direction. These actions will be set on an action queue. 
-- The queue will have the specific steps, in order, for the NPC to be able to do 
-- something (example, go to a specific place and put a chest there). The 
-- fundamental actions are added to the action queue to make a complete task for the NPC.

npc.actions = {}

function npc.actions.rotate(args)
  local self = args.self
  local dir = args.dir
  local yaw = 0
  self.rotate = 0
  if dir == npc.direction.north then
    yaw = 315
  elseif dir == npc.direction.east then
    yaw = 225
  elseif dir == npc.direction.south then
    yaw = 135
  elseif dir == npc.direction.west then
    yaw = 45
  end
  self.object:setyaw(yaw)
end

-- This function will make the NPC walk one step on a 
-- specifc direction. One step means one node. It returns 
-- true if it can move on that direction, and false if there is an obstacle
function npc.actions.walk_step(args)
  local self = args.self
  local dir = args.dir
  local vel = {}
  if dir == npc.direction.north then
    vel = {x=0, y=0, z=1}
  elseif dir == npc.direction.east then
    vel = {x=1, y=0, z=0}
  elseif dir == npc.direction.south then
    vel = {x=0, y=0, z=-1}
  elseif dir == npc.direction.west then
    vel = {x=-1, y=0, z=0}
  end
  set_animation(self, "walk")
  npc.rotate({self=self, dir=dir})
  self.object:setvelocity(vel)
end

-- This action makes the NPC stand and remain like that
function npc.actions.stand(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set stand animation
  set_animation(self, "stand")
end

-- This action makes the NPC sit on the node where it is
function npc.actions.sit(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_SIT_START,
        y = npc.ANIMATION_SIT_END},
        self.animation.speed_normal, 0)
end

-- This action makes the NPC lay on the node where it is
function npc.actions.lay(args)
  local self = args.self
  -- Stop NPC
  self.object:setvelocity({x=0, y=0, z=0})
  -- Set sit animation
  self.object:set_animation({
        x = npc.ANIMATION_LAY_START,
        y = npc.ANIMATION_LAY_END},
        self.animation.speed_normal, 0)
end
