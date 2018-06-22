-- Price table for items bought/sold by NPC traders by Zorman2000
-- This table should be globally accessible so that other mods can set
-- prices as they see fit.

npc.trade.prices = {
  currency = {
    tier1 = "tier1",
    tier2 = "tier2",
    tier3 = "tier3"
  }
}
-- Table that contains the prices
local price_table = {}
-- Currency table
-- Define default currency (based on lumps from default)
local currency_table = {
  tier1 = {string = "default:gold_lump", name = "Gold lump"},
  tier2 = {string = "default:copper_lump", name = "Copper lump"},
  tier3 = {string = "default:iron_lump", name = "Iron lump"}
}

-- Functions
function npc.trade.prices.update(item_name, tier, count)
	for key,value in pairs(price_table) do
    if key == item_name then
      value = {tier=currency_table[tier].string, count=count}
      return
    end
  end
  return nil
end

function npc.trade.prices.get(item_name)
  local price_entry = price_table[item_name]
  if price_entry then
    return price_entry
  end
  return nil
end

function npc.trade.prices.add(item_name, tier, count)
	if npc.trade.prices.get(item_name) == nil then
		price_table[item_name] = {tier=currency_table[tier].string, count=count}
	else
		npc.trade.prices.update(item_name, tier, count)
	end
end

function npc.trade.prices.remove(item_name)
  price_table[item_name] = nil
end

-- Gets all the item for a specified budget
function npc.trade.prices.get_items_for_currency_count(tier, count, price_factor)
  local result = {}
  --minetest.log("Currency quantity: "..dump(count))
  for item_name, price in pairs(price_table) do
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

-- Accepts table in format :
-- {string = "itemstring", name = "Currency Item Name"}
function npc.trade.prices.set_currency(tier1, tier2, tier3)
  currency_table = {
    tier1 = tier1,
    tier2 = tier2,
    tier3 = tier3
  }
end

function npc.trade.prices.get_currency_name(tier)
  return currency_table[tier].name
end

function npc.trade.prices.get_currency_itemstring(tier)
  return currency_table[tier].string
end


-- This method will compare the given item string to the
-- currencies set in the currencies table. Returns true if
-- itemstring is a currency.
function npc.trade.prices.is_item_currency(itemstring)
  if npc.get_item_name(itemstring) == currency_table.tier3.string
    or npc.get_item_name(itemstring) == currency_table.tier2.string
    or npc.get_item_name(itemstring) == currency_table.tier1.string then
    return true
  end
  return false
end

-- Default definitions for in-game items
-- Tier 3 items: cheap items
price_table["default:cobble"] =               {tier = currency_table["tier3"].string, count = 0.1}
price_table["flowers:geranium"] =             {tier = currency_table["tier3"].string, count = 0.5}
price_table["default:apple"]  =               {tier = currency_table["tier3"].string, count = 1}
price_table["vessels:drinking_glass"] =       {tier = currency_table["tier3"].string, count = 1}
price_table["default:tree"]  =                {tier = currency_table["tier3"].string, count = 2}
price_table["flowers:rose"] =                 {tier = currency_table["tier3"].string, count = 2}
price_table["flowers:dandelion_yellow"]=      {tier = currency_table["tier3"].string, count = 2}
price_table["flowers:dandelion_white"] =      {tier = currency_table["tier3"].string, count = 2}
price_table["default:stone"]  =               {tier = currency_table["tier3"].string, count = 2}
price_table["farming:seed_cotton"] =          {tier = currency_table["tier3"].string, count = 3}
price_table["farming:seed_wheat"] =           {tier = currency_table["tier3"].string, count = 3}
price_table["default:clay_lump"] =            {tier = currency_table["tier3"].string, count = 3}
price_table["default:wood"]          =        {tier = currency_table["tier3"].string, count = 3}
price_table["mobs:meat_raw"]  =               {tier = currency_table["tier3"].string, count = 4}
price_table["flowers:chrysanthemum_green"] =  {tier = currency_table["tier3"].string, count = 4}
price_table["default:sapling"]       =        {tier = currency_table["tier3"].string, count = 5}
price_table["mobs:meat"]  =                   {tier = currency_table["tier3"].string, count = 5}
price_table["mobs:leather"]  =                {tier = currency_table["tier3"].string, count = 6}
price_table["default:sword_stone"]  =         {tier = currency_table["tier3"].string, count = 6}
price_table["default:shovel_stone"]  =        {tier = currency_table["tier3"].string, count = 6}
price_table["default:axe_stone"]  =           {tier = currency_table["tier3"].string, count = 6}
price_table["farming:hoe_stone"]  =           {tier = currency_table["tier3"].string, count = 6}
price_table["default:pick_stone"]  =          {tier = currency_table["tier3"].string, count = 7}
price_table["bucket:bucket_empty"] =          {tier = currency_table["tier3"].string, count = 10}
price_table["farming:cotton"] =               {tier = currency_table["tier3"].string, count = 15}
price_table["farming:bread"]  =               {tier = currency_table["tier3"].string, count = 20}

-- Tier 2 items: medium priced items

-- Tier 1 items: expensive items
price_table["default:mese_crystal"]       = {tier = currency_table["tier1"].string, count = 45}
price_table["default:diamond"]            = {tier = currency_table["tier1"].string, count = 90}
price_table["advanced_npc:marriage_ring"] = {tier = currency_table["tier1"].string, count = 100}