-- NPC trading abilities by Zorman2000

npc.trade = {}

npc.trade.CASUAL = "casual"
npc.trade.TRADER = "trader"
npc.trade.NONE = "none"

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