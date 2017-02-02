-- Trading code for Advanced NPC by Zorman2000

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
  text = "I'm looking to buy some items, are  you interested?",
  casual_trade_type = npc.trade.OFFER_BUY,
  responses = {
    [1] = {
      text = "Sell",
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
      text = "Buy",
      action_type = "function",
      response_id = 1,
      action = function(self, player)
        npc.trade.show_trade_offer_formspec(self, player, npc.trade.OFFER_SELL)
      end
    }
  }
}

-- Dedicated trade dialogue prompt
npc.trade.DEDICATED_TRADER_PROMPT = {
  text = "Hello there, would you like to trade?",
  is_dedicated_trade_prompt = true,
  responses = {
    [1] = {
      text = "Buy",
      action_type = "function",
      response_id = 1,
      action = function(self, player)
        npc.trade.show_dedicated_trade_formspec(self, player, npc.trade.OFFER_SELL)
      end
    },
    [2] = {
      text = "Sell",
      action_type = "function",
      response_id = 2,
      action = function(self, player)
        npc.trade.show_dedicated_trade_formspec(self, player, npc.trade.OFFER_BUY)
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


function npc.trade.show_dedicated_trade_formspec(self, player, offers_type)

  -- Choose the correct offers
  local offers = self.trader_data.buy_offers
  local menu_offer_type = "sell"
  if offers_type == npc.trade.OFFER_SELL then
    offers = self.trader_data.sell_offers
    menu_offer_type = "buy"
  end

  -- Create a grid with the items for trade offer
  local max_columns = 4
  local current_x = 0.2
  local current_y = 0.5
  local current_col = 1
  local current_row = 1
  local formspec = "size[8.9,8.2]"..
                default.gui_bg..
                default.gui_bg_img..
                default.gui_slots..
                "label[0.2,0.05;Click on the price button to "..menu_offer_type.." item]"
  for i = 1, #offers do
    local price_item_name = minetest.registered_items[npc.get_item_name(offers[i].price)].description
    formspec = formspec.. 
      "box["..current_x..","..current_y..";2,2.3;#212121]"..
      "item_image["..(current_x + 0.45)..","..(current_y + 0.15)..";1.3,1.3;"..npc.get_item_name(offers[i].item).."]"..
      "item_image_button["..(current_x + 1.15)..","..(current_y + 1.4)..";1,1;"..offers[i].price..";price"..i..";]"..
      "label["..(current_x + 0.15)..","..(current_y + 1.7)..";Price]"
    current_x = current_x + 2.1
    current_col = current_col + 1
    if current_col > 4 then
      current_col = 1
      current_x = 0.2
      current_y = current_y + 2.4
    end
  end

  formspec = formspec .. "button_exit[2.5,7.9;3.9,0.5;exit;Nevermind]"

  minetest.show_formspec(player:get_player_name(), "advanced_npc:dedicated_trading_offers", formspec)

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

-- This function generates and stores on the NPC data trade
-- offers depending on the trader status. 
function npc.trade.generate_trade_offers_by_status(self)
  -- Get trader status
  local status = self.trader_data.trader_status
  -- Check what is the trader status
  if status == npc.trade.NONE then
    -- For none, clear all offers
    self.trader_data.buy_offers = {}
    self.trader_data.sell_offers = {}
  elseif status == npc.trade.CASUAL then
    -- For casual, generate one buy and one sell offer
    self.trader_data.buy_offers = {
      [1] = npc.trade.get_casual_trade_offer(self, npc.trade.OFFER_BUY)
    }
    self.trader_data.sell_offers = {
      [1] = npc.trade.get_casual_trade_offer(self, npc.trade.OFFER_SELL)
    }
  elseif status == npc.trade.TRADER then
    -- Get trade offers for a dedicated trader
    local offers = npc.trade.get_dedicated_trade_offers(self)
    -- Store buy offers
    for i = 1, #offers.buy do
      table.insert(self.trader_data.buy_offers, offers.buy[i])
    end
    -- Store sell offers
    for i = 1, #offers.sell do
      table.insert(self.trader_data.sell_offers, offers.sell[i])
    end
  end
end

-- Convenience method that retrieves all the currency
-- items that a NPC has on his/her inventory
function npc.trade.get_currencies_in_inventory(self)
  local result = {}
  local tier3 = npc.inventory_contains(self, npc.trade.prices.currency.tier3.string)
  local tier2 = npc.inventory_contains(self, npc.trade.prices.currency.tier2.string)
  local tier1 = npc.inventory_contains(self, npc.trade.prices.currency.tier1.string)
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
      npc.trade.prices.get_items_for_currency_count(chosen_tier.name, chosen_tier.count, 0.5)
    -- Select a random item from the buyable items
    local item_set = {}
    for item,price_info in pairs(buyable_items) do
      table.insert(item_set, item)
    end
    local item = item_set[math.random(#item_set)]
    -- Choose buying quantity. Since this is a buy offer, NPC will buy items 
    -- at half the price. Therefore, NPC will always ask for even quantities
    -- so that the price count is always an integer number
    local amount_to_buy = math.random(buyable_items[item].min_buyable_item_count, buyable_items[item].max_buyable_item_count)
    -- Create trade offer
    minetest.log("Buyable item: "..dump(buyable_items[item]))
    result = npc.trade.create_offer(npc.trade.OFFER_BUY, item, buyable_items[item].price, buyable_items[item].min_buyable_item_price, amount_to_buy)
  else
    -- Make sell offer, NPC will sell items to player at regular price
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
    -- Create trade offer
    result = npc.trade.create_offer(npc.trade.OFFER_SELL, npc.get_item_name(item), nil, nil, count)
  end

  return result
end

-- The following function create buy and sell offers for dedicated traders,
-- based on the trader list and the source of items. Initially, it will only
-- be NPC inventories. In the future, it should support both NPC and chest
-- inventories,
function npc.trade.get_dedicated_trade_offers(self)
  local offers = { 
    sell = {},
    buy = {}
  }

  local trade_list = self.trader_data.trade_list.both

  for item_name, trade_info in pairs(trade_list) do
    -- For each item on the trader list, check if it is in the NPC inventory.
    -- If it is, create a sell offer, else create a buy offer if possible.
    local item = npc.inventory_contains(self, item_name)
    if item ~= nil then
      -- Create sell offer for this item. Currently, traders will offer to sell only
      -- of their items to allow the fine control for players to buy what they want.
      -- This requires, however, that the trade offers are re-generated everytime a
      -- sell is made.
      table.insert(offers.sell, npc.trade.create_offer(
        npc.trade.OFFER_SELL, 
        item_name, 
        nil, 
        nil, 
        1)
      )
      -- Set last offer type
      trade_info.last_offer_type = npc.trade.OFFER_SELL
    else
      -- Avoid flipping an item to the buy side if the stock was just depleted
      if trade_info.last_offer_type ~= npc.trade.OFFER_SELL then
        -- Create buy offer for this item
        -- Only do if the NPC can actually afford the items.
        local currencies = npc.trade.get_currencies_in_inventory(self)
        -- Choose a random currency
        local chosen_tier = currencies[math.random(#currencies)]
        -- Get items for this currency
        local buyable_items =
          npc.trade.prices.get_items_for_currency_count(chosen_tier.name, chosen_tier.count, 0.5)
        -- Check if the item from trader list is present in the buyable items list
        for buyable_item, price_info in pairs(buyable_items) do
          if buyable_item == item_name then
            -- If item found, create a buy offer for this item
            -- Again, offers are created for one item only. Buy offers should be removed
            -- after the NPC has bought a certain quantity, say, 5 items.
            table.insert(offers.buy, npc.trade.create_offer(
              npc.trade.OFFER_BUY, 
              item_name, 
              price_info.price, 
              price_info.min_buyable_item_price, 
              price_info.min_buyable_item_count)
            )
            -- Set last offer type
            trade_info.last_offer_type = npc.trade.OFFER_BUY
          end
        end
      end
    end
  end
  return offers
end

-- Creates a trade offer based on the offer type, given item and count. If
-- the offer is a "buy" offer, it is required to provide the price item and
-- the minimum price item count.
function npc.trade.create_offer(offer_type, item, price, min_price_item_count, count)
  local result = {}
  -- Check offer type
  if offer_type == npc.trade.OFFER_BUY then
    -- Get price for the given item
    -- Create price itemstring
    local price_string = price.tier.." "
      ..tostring( min_price_item_count * count )

    -- Build the return object
    result = {
      offer_type = offer_type,
      item = item.." "..count,
      price = price_string
    }
  else
    -- Make sell offer, NPC will sell items to player at regular price
    -- Get and calculate price for this object
    local price_object = npc.trade.prices.table[item]
    -- Check price object, if price < 1 then offer to sell for 1
    if price_object.count < 1 then
      price_object.count = 1
    end
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


-- TODO: THis method needs to be refactored to be able to manage
-- both NPC inventories and chest inventories
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
          "Looks like you can't get what I'm giving you for payment!")
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
      -- Unlock the action timer
      npc.unlock_actions(player_response.npc)
      
      if fields.yes_option then
        npc.trade.perform_trade(player_response.npc, player_name, player_response.trade_offer)
      elseif fields.no_option then
        minetest.chat_send_player(player_name, "Talk to me if you change your mind!")
      end

    end
  end

end)