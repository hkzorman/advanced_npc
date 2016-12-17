-- NPC trading abilities by Zorman2000

npc.trade = {}

npc.trade.CASUAL = "casual"
npc.trade.TRADER = "trader"
npc.trade.NONE = "none"

npc.trade.OFFER_BUY = "buy"
npc.trade.OFFER_SELL = "sell"

-- This table holds all responses for trades  
npc.trade.results = {
  single_trade_offer = {},
  trade_offers = {}
}

-- Casual trader NPC dialogues definition
-- Casual buyer
npc.trade.CASUAL_TRADE_BUY_DIALOGUE = {
  text = "I'm looking to buy some items, are you interested?",
  casual_trade_type = npc.trade.OFFER_BUY,
  responses = {
    [1] = {
      text = "Yes, let's see what are you looking for",
      action_type = "function",
      response_id = 1,
      action = function(self, player)
        npc.trade.show_trade_offer_formspec(self, player, npc.trade.OFFER_BUY)
      end
    }
  }
}

-- Casual seller
npc.trade.CASUAL_TRADE_SELL_DIALOGUE = {
  text = "I have some items to sell, are you interested?",
  casual_trade_type = npc.trade.OFFER_SELL,
  responses = {
    [1] = {
      text = "Yes, let's see what you have",
      action_type = "function",
      response_id = 1,
      action = function(self, player)
        npc.trade.show_trade_offer_formspec(self, player, npc.trade.OFFER_SELL)
      end
    }
  }
}

function npc.trade.show_trade_offer_formspec(self, player, offer_type)
  
  -- Strings for formspec, to include international support later
  local prompt_string = " offers to buy from you"
  local for_string = "for"
  local buy_sell_string = "Sell"

  -- Get offer. As this is casual trading, NPCs will only have
  -- one trade offer
  local trade_offer = self.trader_data.buy_offers[1]
  if offer_type == npc.trade.OFFER_SELL then
    trade_offer = self.trader_data.sell_offers[1]
    prompt_string = " wants to sell to you"
    buy_sell_string = "Buy"
  end

  local formspec = "size[8,4]"..
                default.gui_bg..
                default.gui_bg_img..
                default.gui_slots..
                "label[2,0.1;"..self.nametag..prompt_string.."]"..
                "item_image_button[2,1.3;1.2,1.2;"..trade_offer.item..";item;]"..
                "label[3.75,1.75;"..for_string.."]"..
                "item_image_button[4.8,1.3;1.2,1.2;"..trade_offer.price..";price;]"..
                "button_exit[1,3.3;2.9,0.5;yes_option;"..buy_sell_string.."]"..
                "button_exit[4.1,3.3;2.9,0.5;no_option;"..npc.dialogue.NEGATIVE_ANSWER_LABEL.."]" 

  -- Create entry into results table
  npc.trade.results.single_trade_offer[player:get_player_name()] = {
    trade_offer = trade_offer,
    npc = self
  }
  -- Show formspec to player
  minetest.show_formspec(player:get_player_name(), "advanced_npc:trade_offer", formspec)
end

function npc.trade.get_random_trade_status()
	local chance = math.random(1,10)

	if chance < 3 then
		-- Non-trader
    return npc.trade.NONE
	elseif 3 <= chance and chance <= 7 then
    -- Casual trader
    return npc.trade.CASUAL
	elseif chance > 7 then
    -- Trader by profession
    return npc.trade.TRADER
	end
end

-- Convenience method that retrieves all the currency
-- items that a NPC has on his/her inventory
function npc.trade.get_currencies_in_inventory(self)
  local result = {}
  local tier3 = npc.inventory_contains(self, npc.trade.prices.currency.tier3)
  local tier2 = npc.inventory_contains(self, npc.trade.prices.currency.tier2)
  local tier1 = npc.inventory_contains(self, npc.trade.prices.currency.tier1)
  if tier3 ~= nil then
    table.insert(result, {name = npc.get_item_name(tier3.item_string), 
                          count = npc.get_item_count(tier3.item_string)} )
  end
  if tier2 ~= nil then
    table.insert(result, {name = npc.get_item_name(tier2.item_string), 
                          count = npc.get_item_count(tier2.item_string)} )
  end
  if tier1 ~= nil then
    table.insert(result, {name = npc.get_item_name(tier1.item_string), 
                          count = npc.get_item_count(tier1.item_string)} )
  end

  minetest.log("Found currency in inventory: "..dump(result))
  return result
end

-- This function will return an offer object, based
-- on the items the NPC has.
-- Criteria: The NPC will offer to sell its items
-- if it doesn't has any currency.
function npc.trade.get_casual_trade_offer(self, offer_type)
  local result = {}
  -- Check offer type
  if offer_type == npc.trade.OFFER_BUY then
    -- Create buy offer based on what the NPC can actually buy
    local currencies = npc.trade.get_currencies_in_inventory(self)
    -- Choose a random currency
    local chosen_tier = currencies[math.random(#currencies)]
    -- Get items for this currency
    local buyable_items = 
      npc.trade.prices.get_items_for_currency_count(chosen_tier.name, chosen_tier.count)
    -- Select a random item from the buyable items
    local item_set = {}
    for item,price in pairs(buyable_items) do
      table.insert(item_set, item)
    end
    local item = item_set[math.random(#item_set)]
    -- Choose buying quantity. Since this is a buy offer, NPC will buy items 
    -- at half the price. Therefore, NPC will always ask for even quantities
    -- so that the price count is always an integer number
    local amount_to_buy = math.random(1,5) * 2
    local price_item_count = buyable_items[item].count * ((amount_to_buy) / 2)
    -- Increase the amount to buy if the result of the price is a decimal number
    while price_item_count % 1 ~= 0 do
      amount_to_buy = amount_to_buy + 1
      price_item_count = buyable_items[item].count * ((amount_to_buy) / 2)
    end
    -- Create price itemstring
    local price_string = buyable_items[item].tier.." "
      ..tostring( buyable_items[item].count * (amount_to_buy / 2) )

    -- Build the return object
    result = {
      offer_type = offer_type,
      item = item.." "..amount_to_buy,
      price = price_string
    }
  else
    -- Make sell offer, NPC will sell items to NPC at regular price
    -- NPC will also offer items from their inventory
    local sellable_items = {}
    for i = 1, #self.inventory do
      if self.inventory[i] ~= "" then
        if npc.trade.prices.is_item_currency(self.inventory[i]) == false then
          table.insert(sellable_items, self.inventory[i])
        end
      end
    end
    -- Choose a random item from the sellable items
    local item = sellable_items[math.random(#sellable_items)]
    -- Choose how many of this item will be sold to player
    local count = math.random(npc.get_item_count(item))
    -- Get and calculate price for this object
    minetest.log("Item: "..dump(item)..", name: "..dump(npc.get_item_name(item)))
    local price_object = npc.trade.prices.table[npc.get_item_name(item)]
    local price_string = price_object.tier.." "..tostring(price_object.count * count)
    -- Build return object
    result = {
     offer_type = offer_type,
     item = npc.get_item_name(item).." "..count,
     price = price_string
    }
  end

  return result
end

function npc.trade.perform_trade(self, player_name, offer)

  local item_stack = ItemStack(offer.item)
  local price_stack = ItemStack(offer.price)
  local inv = minetest.get_inventory({type = "player", name = player_name})

  -- Check if offer is a buy or sell
  if offer.offer_type == npc.trade.OFFER_BUY then
    -- If NPC is buying from player, then player loses item, gets price
    -- Check player has the item being buyed
    if inv:contains_item("main", item_stack) then
      -- Check if there is enough room to add the price item to player
      if inv:room_for_item("main", price_stack) then
      -- Remove item from player
        inv:remove_item("main", item_stack)
        -- Add item to NPC's inventory
        npc.add_item_to_inventory_itemstring(self, offer.item)
        -- Add price items to player
        inv:add_item("main", price_stack)
        -- Send message to player
        minetest.chat_send_player(player_name, "Thank you!")
      else
        minetest.chat_send_player(player_name, 
          "Looks like you can't what I'm giving you for payment!")
      end
    else
      minetest.chat_send_player(player_name, "Looks like you don't have what I want to buy...")
    end
  else
    -- If NPC is selling to the player, then player gives price and gets
    -- item, NPC loses item and gets price
    -- Check NPC has the required item to pay
    if inv:contains_item("main", price_stack) then
      -- Check if there is enough room to add the item to player
      if inv:room_for_item("main", item_stack) then
      -- Remove item from player
        inv:remove_item("main", price_stack)
        -- Add item to NPC's inventory
        npc.add_item_to_inventory_itemstring(self, offer.price)
        -- Add price items to player
        inv:add_item("main", item_stack)
        -- Send message to player
        minetest.chat_send_player(player_name, "Thank you!")
      else
        minetest.chat_send_player(player_name, "Looks like you can't carry anything else...")
      end
    else
      minetest.chat_send_player(player_name, "Looks like you don't have what I'm asking for!")
    end
  end
end


-- Handler for chat formspec
minetest.register_on_player_receive_fields(function (player, formname, fields)
  -- Additional checks for other forms should be handled here
  -- Handle yes/no dialogue
  if formname == "advanced_npc:trade_offer" then
    local player_name = player:get_player_name()

    if fields then
      local player_response = npc.trade.results.single_trade_offer[player_name]
      if fields.yes_option then
        npc.trade.perform_trade(player_response.npc, player_name, player_response.trade_offer)
      elseif fields.no_option then
        minetest.chat_send_player(player_name, "Talk to me if you change your mind!")
      end
    end
  end

end)