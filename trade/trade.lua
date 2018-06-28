-- Trading code for Advanced NPC by Zorman2000

npc.trade = {}

npc.trade.CASUAL = "casual"
npc.trade.TRADER = "trader"
npc.trade.NONE = "none"

npc.trade.OFFER_BUY = "buy"
npc.trade.OFFER_SELL = "sell"

-- This variable establishes how much items a dedicated
-- trader will buy until retiring the offer
npc.trade.DEDICATED_MAX_BUY_AMOUNT = 5

-- This table holds all responses for trades  
npc.trade.results = {
    single_trade_offer = {},
    trade_offers = {},
    custom_trade_offer = {}
}

-- This is the text to be shown each time the NPC has more
-- than one custom trade options to choose from
npc.trade.CUSTOM_TRADES_PROMPT_TEXT = "Hi there, how can I help you today?"

-- Casual trader NPC dialogues definition
-- Casual buyer
npc.dialogue.register_dialogue({
    text = "I'm looking to buy some items, are you interested?",
    --casual_trade_type = npc.trade.OFFER_BUY,
    tags = {"default_casual_trade_dialogue", "buy_offer"},
    --dialogue_type = npc.dialogue.dialogue_type.casual_trade,
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
})

-- npc.trade.CASUAL_TRADE_BUY_DIALOGUE = {
--   text = "I'm looking to buy some items, are  you interested?",
--   casual_trade_type = npc.trade.OFFER_BUY,
--   dialogue_type = npc.dialogue.dialogue_type.casual_trade,
--   responses = {
--     [1] = {
--       text = "Sell",
--       action_type = "function",
--       response_id = 1,
--       action = function(self, player)
--         npc.trade.show_trade_offer_formspec(self, player, npc.trade.OFFER_BUY)
--       end
--     }
--   }
-- }

-- Casual seller
npc.dialogue.register_dialogue({
    text = "I have some items to sell, are you interested?",
    --dialogue_type = npc.dialogue.dialogue_type.casual_trade,
    tags = {"default_casual_trade_dialogue", "sell_offer"},
    --casual_trade_type = npc.trade.OFFER_SELL,
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
})

-- npc.trade.CASUAL_TRADE_SELL_DIALOGUE = {
--   text = "I have some items to sell, are you interested?",
--   dialogue_type = npc.dialogue.dialogue_type.casual_trade,
--   casual_trade_type = npc.trade.OFFER_SELL,
--   responses = {
--     [1] = {
--       text = "Buy",
--       action_type = "function",
--       response_id = 1,
--       action = function(self, player)
--         npc.trade.show_trade_offer_formspec(self, player, npc.trade.OFFER_SELL)
--       end
--     }
--   }
-- }

-- Dedicated trade dialogue prompt
npc.dialogue.register_dialogue({
    text = "Hello there, would you like to trade?",
    tags = {npc.dialogue.tags.DEFAULT_DEDICATED_TRADE},
    dialogue_type = npc.dialogue.dialogue_type.dedicated_trade,
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
        },
        [3] = {
            text = "Other",
            action_type = "function",
            response_id = 3,
            action = function(self, player)
                local dialogue = npc.dialogue.create_custom_trade_options(self, player)
                npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
            end
        }
    }
})
-- npc.trade.DEDICATED_TRADER_PROMPT = {
--   text = "Hello there, would you like to trade?",
--   dialogue_type = npc.dialogue.dialogue_type.dedicated_trade,
--   responses = {
--     [1] = {
--       text = "Buy",
--       action_type = "function",
--       response_id = 1,
--       action = function(self, player)
--         npc.trade.show_dedicated_trade_formspec(self, player, npc.trade.OFFER_SELL)
--       end
--     },
--     [2] = {
--       text = "Sell",
--       action_type = "function",
--       response_id = 2,
--       action = function(self, player)
--         npc.trade.show_dedicated_trade_formspec(self, player, npc.trade.OFFER_BUY)
--       end
--     },
--     [3] = {
--       text = "Other",
--       action_type = "function",
--       response_id = 3,
--       action = function(self, player)
--         local dialogue = npc.dialogue.create_custom_trade_options(self, player)
--         npc.dialogue.process_dialogue(self, dialogue, player:get_player_name())
--       end
--     }
--   }
-- }

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
            "label[2,0.1;"..self.npc_name..prompt_string.."]"..
            "item_image_button[2,1.3;1.2,1.2;"..trade_offer.item..";item;]"..
            "label[3.75,1.75;"..for_string.."]"..
            "item_image_button[4.8,1.3;1.2,1.2;"..trade_offer.price[1]..";price;]"..
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
        local price_item_name = minetest.registered_items[npc.get_item_name(offers[i].price[1])].description
        local count_label = ""
        if npc.get_item_count(offers[i].item) > 1 then
            count_label = "label["..(current_x + 1.35)..","..(current_y + 1)..";"..npc.get_item_count(offers[i].item).."]"
        end
        formspec = formspec..
                "box["..current_x..","..current_y..";2,2.3;#212121]"..
                "item_image_button["..(current_x + 0.45)..","..(current_y + 0.15)..";1.3,1.3;"..npc.get_item_name(offers[i].item)..";item"..i..";]"..
                count_label..
                "item_image_button["..(current_x + 1.15)..","..(current_y + 1.4)..";1,1;"..offers[i].price[1]..";price"..i..";]"..
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

    -- Create entry into results table
    npc.trade.results.trade_offers[player:get_player_name()] = {
        offers_type = offers_type,
        offers = offers,
        npc = self
    }

    minetest.show_formspec(player:get_player_name(), "advanced_npc:dedicated_trading_offers", formspec)

end

-- For the moment, the trade offer for custom trade is always of sell type
function npc.trade.show_custom_trade_offer(self, player, offer)
    local for_string = "for"
    -- Create payments grid. Try to center it. When there are 4
    -- payment options, a grid is to be displayed.
    local price_count = #offer.price
    local start_x = 2
    local margin_x = 0
    local start_y = 1.45
    if price_count == 2 then
        start_x = 1.5
        margin_x = 0.3
    elseif price_count == 3 then
        start_x = 1.15
        margin_x = 0.85
    elseif price_count == 4 then
        start_x = 1.5
        start_y = 0.8
        margin_x = 0.3
    end

    -- Create payment grid
    local price_grid = ""
    for i = 1, #offer.price do
        price_grid = price_grid.."item_image_button["..start_x..","..start_y..";1,1;"..offer.price[i]..";price"..i..";]"
        if #offer.price == 4 and i == 2 then
            start_x = 1.5
            start_y = start_y + 1
        else
            start_x = start_x + 1
        end
    end

    local formspec = "size[8,4]"..
            default.gui_bg..
            default.gui_bg_img..
            default.gui_slots..
            "label[2,0.1;"..self.npc_name..": "..offer.dialogue_prompt.."]"..
            price_grid..
            "label["..(margin_x + 3.75)..",1.75;"..for_string.."]"..
            "item_image_button["..(margin_x + 4.8)..",1.3;1.2,1.2;"..offer.item..";item;]"..
            "button_exit[1,3.3;2.9,0.5;yes_option;"..offer.button_prompt.."]"..
            "button_exit[4.1,3.3;2.9,0.5;no_option;"..npc.dialogue.NEGATIVE_ANSWER_LABEL.."]"

    -- Create entry into results table
    npc.trade.results.custom_trade_offer[player:get_player_name()] = {
        trade_offer = offer,
        npc = self
    }
    -- Show formspec to player
    minetest.show_formspec(player:get_player_name(), "advanced_npc:custom_trade_offer", formspec)
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
        -- Clear current offers
        self.trader_data.buy_offers = {}
        self.trader_data.sell_offers = {}
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
    local tier3 = npc.inventory_contains(self, npc.trade.prices.get_currency_itemstring("tier3"))
    local tier2 = npc.inventory_contains(self, npc.trade.prices.get_currency_itemstring("tier2"))
    local tier1 = npc.inventory_contains(self, npc.trade.prices.get_currency_itemstring("tier1"))
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

    --minetest.log("Found currency in inventory: "..dump(result))
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
        --minetest.log("Buyable item: "..dump(buyable_items[item]))
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
        -- Check if there are no sellable items to avoid crash
        if #sellable_items > 0 then
            -- Choose a random item from the sellable items
            local item = sellable_items[math.random(#sellable_items)]
            -- Choose how many of this item will be sold to player
            local count = math.random(npc.get_item_count(item))
            -- Create trade offer
            result = npc.trade.create_offer(npc.trade.OFFER_SELL, npc.get_item_name(item), nil, nil, count)
        end
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

    local trade_list = self.trader_data.trade_list

    npc.log("INFO", "NPC Inventory: "..dump(self.inventory))

    for item_name, trade_info in pairs(trade_list) do
        -- Abort if more than 12 buy or sell offers are made
        if table.getn(offers.sell) >= 12 or table.getn(offers.buy) >= 12 then
            break
        end
        -- For each item on the trader list, check if it is in the NPC inventory.
        -- If it is, create a sell offer, else create a buy offer if possible.
        -- Also, avoid creating sell offers immediately if the item was just bought
        local item = npc.inventory_contains(self, item_name)
        minetest.log("Searched item: "..dump(item_name))
        minetest.log("Found: "..dump(item))
        if item ~= nil and trade_info.last_offer_type ~= npc.trade.OFFER_BUY then
            -- Check if item can be sold
            if trade_info.item_sold_count == nil
                    or (trade_info.item_sold_count ~= nil
                        and (trade_info.max_item_sell_count
                            and trade_info.item_sold_count < trade_info.max_item_sell_count)) then
                -- This check makes sure that the NPC will keep max_item_sell_count at any time.
                if trade_info.amount_to_keep == nil or (trade_info.amount_to_keep ~= nil
                        and trade_info.amount_to_keep < ItemStack(item.item_string):get_count()) then
                    -- Create sell offer for this item. Currently, traders will offer to sell only
                    -- one of their items to allow the fine control for players to buy what they want.
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
                end
            else
                -- Clear the trade info for this item
                trade_info.item_sold_count = 0
            end

        else
            -- Avoid flipping an item to the buy side if the stock was just depleted
            if trade_info.last_offer_type ~= npc.trade.OFFER_SELL then
                -- Create buy offer for this item
                -- Only do if the NPC can actually afford the items.
                local currencies = npc.trade.get_currencies_in_inventory(self)
                -- Check if currency isn't empty
                if #currencies > 0 then
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
                            if trade_info.item_bought_count == nil
                                    or (trade_info.item_bought_count ~= nil
                                    and (trade_info.max_item_buy_count and trade_info.item_bought_count <= trade_info.max_item_buy_count
                                    or trade_info.item_bought_count <= npc.trade.DEDICATED_MAX_BUY_AMOUNT)) then
                                -- Create trade offer for this item
                                table.insert(offers.buy, npc.trade.create_offer(
                                    npc.trade.OFFER_BUY,
                                    item_name,
                                    price_info.price,
                                    price_info.min_buyable_item_price,
                                    price_info.min_buyable_item_count)
                                )
                                -- Set last offer type
                                trade_info.last_offer_type = npc.trade.OFFER_BUY
                            else
                                -- Clear the trade info for this item
                                trade_info.item_bought_count = 0
                            end
                        end
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
        -- Price is always an array, in this case of size 1
        result = {
            offer_type = offer_type,
            item = item.." "..count,
            price = {[1] = price_string}
        }
    else
        -- Make sell offer, NPC will sell items to player at regular price
        -- Get and calculate price for this object
        local price_object = npc.trade.prices.get(item)
        if price_object == nil then
            npc.log("WARNING", "Found nil price for item: "..dump(item))
            return nil
        end
        -- Check price object, if price < 1 then offer to sell for 1
        if price_object.count < 1 then
            price_object.count = 1
        end
        local price_string = price_object.tier.." "..tostring(price_object.count * count)
        -- Build return object
        -- Price is always an array, in this case of size 1
        result = {
            offer_type = offer_type,
            item = npc.get_item_name(item).." "..count,
            price = {[1] = price_string}
        }
    end

    return result

end

-- A custom sell trade offer is a special type of trading the NPC can
-- have where a different prompt and multiple payment objects are
-- required from the player. A good example is offering to repair a sword,
-- where the player has to give an amount of currency and the sword to
-- repair in exchange to get a fully repaired sword.
-- For the moment being, only sell is supported.
function npc.trade.create_custom_sell_trade_offer(option_prompt, dialogue_prompt, button_prompt, item, payments)
    return {
        offer_type = npc.OFFER_SELL,
        option_prompt = option_prompt,
        dialogue_prompt = dialogue_prompt,
        button_prompt = button_prompt,
        item = item,
        price = payments
    }
end


-- TODO: This method needs to be refactored to be able to manage
-- both NPC inventories and chest inventories.
-- Returns true if trade was possible, else returns false.
function npc.trade.perform_trade(self, player_name, offer)

    local item_stack = ItemStack(offer.item)
    -- Create item stacks for each price item
    local price_stacks = {}
    for i = 1, #offer.price do
        table.insert(price_stacks, ItemStack(offer.price[i]))
    end
    local inv = minetest.get_inventory({type = "player", name = player_name})

    -- Check if offer is a buy or sell
    if offer.offer_type == npc.trade.OFFER_BUY then
        -- If NPC is buying from player, then player loses item, gets price
        -- Check player has the item being buyed
        if inv:contains_item("main", item_stack) then
            -- Check if there is enough room to add the price item to player
            for i = 1, #price_stacks do
                if inv:room_for_item("main", price_stacks[i]) then
                    -- Remove item from player
                    inv:remove_item("main", item_stack)
                    -- Remove price item(s) from NPC
                    for j = 1, #price_stacks do
                        npc.take_item_from_inventory_itemstring(self, price_stacks[j])
                    end
                    -- Add item to NPC's inventory
                    npc.add_item_to_inventory_itemstring(self, offer.item)
                    -- Add price items to player
                    for j = 1, #price_stacks do
                        inv:add_item("main", price_stacks[j])
                    end
                    -- Send message to player
                    npc.chat(self.npc_name, player_name, "Thank you!")
                    return true
                else
                    npc.chat(self.npc_name, player_name,
                        "Looks like you can't get what I'm giving you for payment!")
                    return false
                end
            end
        else
            npc.chat(self.npc_name, player_name,
                "Looks like you don't have what I want to buy...")
            return false
        end
    else
        -- If NPC is selling to the player, then player gives price and gets
        -- item, NPC loses item and gets price.
        for i = 1, #price_stacks do
            -- Check NPC has the required item to pay
            if inv:contains_item("main", price_stacks[i]) then
                -- Check if there is enough room to add the item to player
                if inv:room_for_item("main", item_stack) then
                    -- Remove price item from player
                    for j = 1, #price_stacks do
                        inv:remove_item("main", price_stacks[j])
                    end
                    -- Remove sell item from NPC
                    npc.take_item_from_inventory_itemstring(self, offer.item)
                    -- Add price to NPC's inventory
                    for i = 1, #offer.price do
                        npc.add_item_to_inventory_itemstring(self, offer.price[i])
                    end
                    -- Add item items to player
                    inv:add_item("main", item_stack)
                    -- Send message to player
                    npc.chat(self.npc_name, player_name, "Thank you!")
                    return true
                else
                    npc.chat(self.npc_name, player_name,
                        "Looks like you can't carry anything else...")
                    return false
                end
            else
                npc.chat(self.npc_name, player_name,
                    "Looks like you don't have what I'm asking for!")
                return false
            end
        end
    end
end

-- Handler for chat formspec
minetest.register_on_player_receive_fields(function (player, formname, fields)
    -- Additional checks for other forms should be handled here
    -- Handle casual trade dialogue
    if formname == "advanced_npc:trade_offer" then
        local player_name = player:get_player_name()

        if fields then
            local player_response = npc.trade.results.single_trade_offer[player_name]
            -- Unlock the action timer
            npc.exec.set_ready_state(player_response.npc)

            if fields.yes_option then
                npc.trade.perform_trade(player_response.npc, player_name, player_response.trade_offer)
            elseif fields.no_option then
                minetest.chat_send_player(player_name, "Talk to me if you change your mind!")
            end

        end
    elseif formname == "advanced_npc:dedicated_trading_offers" then
        local player_name = player:get_player_name()

        if fields then
            local player_response = npc.trade.results.trade_offers[player_name]
            -- Unlock the action timer
            npc.exec.set_ready_state(player_response.npc)

            local trade_offers = npc.trade.results.trade_offers[player_name].offers
            -- Check which price was clicked
            for i = 1, #trade_offers do
                local price_button = "price"..tostring(i)
                if fields[price_button] then
                    local trade_result = npc.trade.perform_trade(player_response.npc, player_name, trade_offers[i])
                    if trade_result == true then
                        -- Lock actions
                        npc.exec.set_input_wait_state(player_response.npc)
                        -- Account for buyed items
                        if player_response.offers_type == npc.trade.OFFER_BUY then
                            -- Increase the item bought count
                            local offer_item_name = npc.get_item_name(trade_offers[i].item)
                            --minetest.log("Bought item name: "..dump(offer_item_name))
                            --minetest.log(dump(player_response.npc.trader_data.trade_list[offer_item_name]))
                            -- Check if this item has been bought before
                            if player_response.npc.trader_data.trade_list[offer_item_name].item_bought_count == nil then
                                -- Set first count to 1
                                player_response.npc.trader_data.trade_list[offer_item_name].item_bought_count = 1
                            else
                                -- Increase count
                                player_response.npc.trader_data.trade_list[offer_item_name].item_bought_count
                                = player_response.npc.trader_data.trade_list[offer_item_name].item_bought_count + 1
                            end
                        else
                            -- Also count how many items are sold
                            local offer_item_name = npc.get_item_name(trade_offers[i].item)
                            -- Check if this item has been sold before
                            if player_response.npc.trader_data.trade_list[offer_item_name].item_sold_count == nil then
                                -- Set first count to 1
                                player_response.npc.trader_data.trade_list[offer_item_name].item_sold_count = 1
                            else
                                -- Increase count
                                player_response.npc.trader_data.trade_list[offer_item_name].item_sold_count
                                = player_response.npc.trader_data.trade_list[offer_item_name].item_sold_count + 1
                            end
                        end
                        -- Re-generate trade offers
                        npc.trade.generate_trade_offers_by_status(player_response.npc)
                        -- Show refreshed formspec again to player
                        npc.trade.show_dedicated_trade_formspec(player_response.npc, player, player_response.offers_type)
                        return true
                    else
                        minetest.close_formspec(player_name, "advanced_npc:dedicated_trading_offers")
                        return false
                    end
                    --minetest.log("Player selected: "..dump(trade_offers[i]))
                end
            end
        end
    elseif formname == "advanced_npc:custom_trade_offer" then
        -- Handle custom trade formspec
        local player_name = player:get_player_name()

        if fields then
            local player_response = npc.trade.results.custom_trade_offer[player_name]
            -- Unlock the action timer
            npc.exec.set_ready_state(player_response.npc)

            if fields.yes_option then
                npc.trade.perform_trade(player_response.npc, player_name, player_response.trade_offer)
            elseif fields.no_option then
                minetest.chat_send_player(player_name, "Talk to me if you change your mind!")
            end

        end
    end
end)