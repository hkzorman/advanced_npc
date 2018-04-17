--
-- User: zorman2000
-- Date: 3/27/18
-- Time: 6:54 PM
--

npc.programs.internal_properties = {
    put_item = "put_item",
    put_multiple_items = "put_multiple_items",
    take_item = "take_item",
    change_trader_status = "trader_status",
    can_receive_gifts = "can_receive_gifts",
    flag = "flag",
    enable_gift_items_hints = "enable_gift_items_hints",
    set_trade_list = "set_trade_list"
}

npc.programs.register("advanced_npc:internal_property_change", function(self, args)

    local properties = {}
    -- Check if this is a just a single property
    if args.property and args.args then
        properties[#properties + 1] = {property = args.property, args = args.args }
    else
        -- Args is an array of property objects as above
        properties = args
    end

    -- Process each property
    for i = 1, #properties do
        local property = properties[i].property
        local args = properties[i].args
        if property == npc.programs.internal_properties.change_trader_status then
            npc.programs.instr.execute(self, "advanced_npc:trade:change_trader_status", args)
        elseif property == npc.programs.internal_properties.set_trade_list then
            npc.programs.instr.execute(self, "advanced_npc:trade:set_trade_list", args)
        elseif property == npc.programs.internal_properties.put_item then
            npc.programs.instr.execute(self, "advanced_npc:inventory_put", args)
        elseif property == npc.programs.internal_properties.put_multiple_items then
            npc.programs.instr.execute(self, "advanced_npc:inventory_put_multiple", args)
        elseif property == npc.programs.internal_properties.take_item then
            npc.programs.instr.execute(self, "advanced_npc:inventory_take", args)
        elseif property == npc.programs.internal_properties.can_receive_gifts then
            local value = args.can_receive_gifts
            -- Set status
            self.can_receive_gifts = value
        elseif property == npc.programs.internal_properties.flag then
            local action = args.action
            if action == "set" then
                -- Adds or overwrites an existing flag and sets it to the given value
                self.flags[args.flag_name] = args.flag_value
            elseif action == "reset" then
                -- Sets value of flag to false or to 0
                local flag_type = type(self.flags[args.flag_name])
                if flag_type == "number" then
                    self.flags[args.flag_name] = 0
                elseif flag_type == "boolean" then
                    self.flags[args.flag_name] = false
                end
            end
        elseif property == npc.schedule_properties.enable_gift_item_hints then
            self.gift_data.enable_gift_items_hints = args.value
        end
    end
end)

