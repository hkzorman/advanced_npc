-- Price table for items bought/sold by NPC traders by Zorman2000
-- This table should be globally accessible so that other mods can set
-- prices as they see fit.

npc.trade.prices = {}

-- Define default currency (based on lumps from default)
npc.trade.prices.currency = {
  tier1 = {string = "default:gold_lump", name = "Gold lump"},
  tier2 = {string = "default:copper_lump", name = "Copper lump"},
  tier3 = {string = "default:iron_lump", name = "Iron lump"}
}

-- TODO: Set the currency depending on available mods

-- Table that contains the prices
npc.trade.prices.table = {}

-- Default definitions for in-game items
-- Tier 3 items: cheap items
npc.trade.prices.table["default:cobble"] =        {tier = npc.trade.prices.currency.tier3.string, count = 0.1}
npc.trade.prices.table["flowers:geranium"] =      {tier = npc.trade.prices.currency.tier3.string, count = 0.5}
npc.trade.prices.table["default:apple"]  =        {tier = npc.trade.prices.currency.tier3.string, count = 1}
npc.trade.prices.table["default:tree"]  =         {tier = npc.trade.prices.currency.tier3.string, count = 2}
npc.trade.prices.table["flowers:rose"] =          {tier = npc.trade.prices.currency.tier3.string, count = 2}
npc.trade.prices.table["default:stone"]  =        {tier = npc.trade.prices.currency.tier3.string, count = 2}
npc.trade.prices.table["farming:seed_cotton"] =   {tier = npc.trade.prices.currency.tier3.string, count = 3}
npc.trade.prices.table["farming:seed_wheat"] =    {tier = npc.trade.prices.currency.tier3.string, count = 3}
npc.trade.prices.table["default:clay_lump"] =     {tier = npc.trade.prices.currency.tier3.string, count = 3}
npc.trade.prices.table["default:wood"]          = {tier = npc.trade.prices.currency.tier3.string, count = 3}
npc.trade.prices.table["mobs:meat_raw"]  =        {tier = npc.trade.prices.currency.tier3.string, count = 4}
npc.trade.prices.table["default:sapling"]       = {tier = npc.trade.prices.currency.tier3.string, count = 5}
npc.trade.prices.table["mobs:meat"]  =            {tier = npc.trade.prices.currency.tier3.string, count = 5}
npc.trade.prices.table["mobs:leather"]  =         {tier = npc.trade.prices.currency.tier3.string, count = 6}
npc.trade.prices.table["default:sword_stone"]  =  {tier = npc.trade.prices.currency.tier3.string, count = 6}
npc.trade.prices.table["default:shovel_stone"]  = {tier = npc.trade.prices.currency.tier3.string, count = 6}
npc.trade.prices.table["default:axe_stone"]  =    {tier = npc.trade.prices.currency.tier3.string, count = 6}
npc.trade.prices.table["default:hoe_stone"]  =    {tier = npc.trade.prices.currency.tier3.string, count = 6}
npc.trade.prices.table["default:pick_stone"]  =   {tier = npc.trade.prices.currency.tier3.string, count = 7}
npc.trade.prices.table["farming:cotton"] =        {tier = npc.trade.prices.currency.tier3.string, count = 15}
npc.trade.prices.table["farming:bread"]  =        {tier = npc.trade.prices.currency.tier3.string, count = 20}

-- Tier 2 items: medium priced items

-- Tier 1 items: expensive items
npc.trade.prices.table["default:mese_crystal"]       = {tier = npc.trade.prices.currency.tier1.string, count = 45}
npc.trade.prices.table["default:diamond"]            = {tier = npc.trade.prices.currency.tier1.string, count = 90}
npc.trade.prices.table["advanced_npc:marriage_ring"] = {tier = npc.trade.prices.currency.tier1.string, count = 100}

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

-- Gets all the item for a specified budget
function npc.trade.prices.get_items_for_currency_count(tier, count, price_factor)
  local result = {}
  --minetest.log("Currency quantity: "..dump(count))
  for item_name, price in pairs(npc.trade.prices.table) do
    -- Check price currency is of the same tier
    if price.tier == tier and price.count <= count then
      result[item_name] = {price = price}

      --minetest.log("Item name: "..dump(item_name)..", Price: "..dump(price))

      local min_buying_item_count = 1
      -- Calculate price NPC is going to buy for
      local buying_price_count = price.count * price_factor
      -- Check if the buying price is not an integer
      if buying_price_count % 1 ~= 0 then
        -- If not, increase the buying item count until we get an integer
        local adjust = 1 / price_factor
        if price.count < 1 then
          adjust = 1 / (price.count * price_factor)
        end
        min_buying_item_count = min_buying_item_count * adjust
      end 
      --minetest.log("Minimum item buy quantity: "..dump(min_buying_item_count))
      --minetest.log("Minimum item price quantity: "..dump(buying_price_count))
      -- Calculate maximum buyable quantity
      local max_buying_item_count = min_buying_item_count
      while ((max_buying_item_count + min_buying_item_count) * buying_price_count <= count) do
        max_buying_item_count = max_buying_item_count + min_buying_item_count
      end
      --minetest.log("Maximum item buy quantity: "..dump(max_buying_item_count))

      result[item_name].min_buyable_item_count = min_buying_item_count
      result[item_name].min_buyable_item_price = buying_price_count
      result[item_name].max_buyable_item_count = max_buying_item_count
    end
  end
  --minetest.log("Final result: "..dump(result))
  return result
end

-- This methods will compare the given item string to the
-- currencies set in the currencies table. Returns true if
-- itemstring is a currency.
function npc.trade.prices.is_item_currency(itemstring)
  if npc.get_item_name(itemstring) == npc.trade.prices.currency.tier3.string
    or npc.get_item_name(itemstring) == npc.trade.prices.currency.tier2.string
    or npc.get_item_name(itemstring) == npc.trade.prices.currency.tier1.string then
    return true
  end
  return false
end
