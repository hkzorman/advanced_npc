-- Price table for items bought/sold by NPC traders by Zorman2000
-- This table should be globally accessible so that other mods can set
-- prices as they see fit.

npc.trade.prices = {}

-- Table that contains the prices
npc.trade.prices.table = {}

-- Default definitions for in-game items
npc.trade.prices.table["default:apple"]  =        {item = "default:iron_ingot",  count = 1}
npc.trade.prices.table["default:stone"]  =        {item = "default:wood_planks", count = 1}
npc.trade.prices.table["default:cobble"] =        {item = "default:iron_ingot",  count = 1}
npc.trade.prices.table["farming:cotton"] =        {item = "default:iron_ingot",  count = 1}
npc.trade.prices.table["farming:bread"]  =        {item = "default:gold_ingot",  count = 1}
npc.trade.prices.table["default:sword_stone"]  =  {item = "default:iron_ingot",  count = 2}
npc.trade.prices.table["default:pick_stone"]  =   {item = "default:iron_ingot",  count = 1}
npc.trade.prices.table["default:shovel_stone"]  = {item = "default:iron_ingot",  count = 2}
npc.trade.prices.table["default:axe_stone"]  =    {item = "default:iron_ingot",  count = 1}
npc.trade.prices.table["default:hoe_stone"]  =    {item = "default:iron_ingot",  count = 1}


-- Functions
function npc.trade.prices.update(item_name, price)
	for key,value in pairs(npc.trade.prices.table) do
    if key == item_name then
      value = price
      return
    end
  end
  return nil
end

function npc.trade.prices.get(item_name)
  for key,value in pairs(npc.trade.prices.table) do
    if key == item_name then
      return {item_name = key, price = value}
    end
  end
  return nil
end

function npc.trade.prices.add(item_name, price)
	if npc.trade.prices.get(item_name) == nil then
		npc.trade.prices.table[item_name] = price
	else
		npc.trade.prices.update(item_name, price)
	end
end

function npc.trade.prices.remove(item_name)
  npc.trade.prices.table[item_name] = nil
end