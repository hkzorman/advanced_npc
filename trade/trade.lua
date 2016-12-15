-- NPC trading abilities by Zorman2000

npc.trade = {}

npc.trade.CASUAL = "casual"
npc.trade.TRADER = "trader"
npc.trade.NONE = "none"

npc.trade.OFFER_BUY = "buy"
npc.trade.OFFER_SELL = "sell"

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
        
      end
    }
  }
}

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
function npc.trade.get_casual_trade_offer(self)
  return {
            offer_type = npc.trade.OFFER_BUY, 
            item = "default:wooden_planks 10", 
            price = "default:iron_lump 20"
         }
end