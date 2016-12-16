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

-- This function will return an offer object, based
-- on the items the NPC has.
-- Criteria: If having a near empty inventory, (< 6) NPC
-- will offer to buy with a 70% chance.
-- If NPC has a near full inventory  (> 10 items), NPC
-- will offer to sell. The prices will be selected using:
-- item_price * (+/- price_item * 0.2) so item will be
-- more or less 20% of the item price.
function npc.trade.get_casual_trade_offer(self, offer_type)
  return {
            offer_type = offer_type, 
            item = "default:wood 10", 
            price = "default:iron_lump 20"
         }
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