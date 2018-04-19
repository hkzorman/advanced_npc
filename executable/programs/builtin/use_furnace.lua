--
-- User: hfranqui
-- Date: 3/12/18
-- Time: 9:00 AM
--

-- This function allows a NPC to use a furnace using only items from
-- its own inventory. Fuel is not provided. Once the furnace is finished
-- with the fuel items the NPC will take whatever was cooked and whatever
-- remained to cook. The function received the position of the furnace
-- to use, and the item to cook in furnace. Item is an itemstring
npc.programs.register("advanced_npc:use_furnace", function(self, args)
    local pos = npc.programs.helper.get_pos_argument(self, args.pos)
    if pos == nil then
        npc.log("WARNING", "Got nil position in 'use_furnace' using args.pos: "..dump(args.pos))
        return
    end

    local enable_usage_marking = args.enable_usage_marking or true
    local item = args.item
    local freeze = args.freeze
    -- Define which items are usable as fuels. The NPC
    -- will mainly use this as fuels to avoid getting useful
    -- items (such as coal lumps) for burning
    local fuels = {"default:leaves",
        "default:pine_needles",
        "default:tree",
        "default:acacia_tree",
        "default:aspen_tree",
        "default:jungletree",
        "default:pine_tree",
        "default:coalblock",
        "farming:straw"}

    -- Check if NPC has item to cook
    local src_item = npc.inventory_contains(self, npc.get_item_name(item))
    if src_item == nil then
        -- Unable to cook item that is not in inventory
        return false
    end

    -- Check if NPC has a fuel item
    for i = 1,9 do
        local fuel_item = npc.inventory_contains(self, fuels[i])

        if fuel_item ~= nil then
            -- Get fuel item's burn time
            local fuel_time =
            minetest.get_craft_result({method="fuel", width=1, items={ItemStack(fuel_item.item_string)}}).time
            local total_fuel_time = fuel_time * npc.get_item_count(fuel_item.item_string)
            npc.log("DEBUG", "Fuel time: "..dump(fuel_time))

            -- Get item to cook's cooking time
            local cook_result =
            minetest.get_craft_result({method="cooking", width=1, items={ItemStack(src_item.item_string)}})
            local total_cook_time = cook_result.time * npc.get_item_count(item)
            npc.log("DEBUG", "Cook: "..dump(cook_result))

            npc.log("DEBUG", "Total cook time: "..total_cook_time
                    ..", total fuel burn time: "..dump(total_fuel_time))

            -- Check if there is enough fuel to cook all items
            if total_cook_time > total_fuel_time then
                -- Don't have enough fuel to cook item. Return the difference
                -- so it may help on trying to acquire the fuel later.
                -- NOTE: Yes, returning here means that NPC could probably have other
                -- items usable as fuels and ignore them. This should be ok for now,
                -- considering that fuel items are ordered in a way where cheaper, less
                -- useless items come first, saving possible valuable items.
                return cook_result.time - fuel_time
            end

            -- Set furnace as used if flag is enabled
            if enable_usage_marking then
                -- Set place as used
                npc.locations.mark_place_used(pos, npc.locations.USE_STATE.USED)
            end

            -- Calculate how much fuel is needed
            local fuel_amount = total_cook_time / fuel_time
            if fuel_amount < 1 then
                fuel_amount = 1
            end

            npc.log("DEBUG", "Amount of fuel needed: "..fuel_amount)

            -- Put this item on the fuel inventory list of the furnace
            local args = {
                player = nil,
                pos = pos,
                inv_list = "fuel",
                item_name = npc.get_item_name(fuel_item.item_string),
                count = fuel_amount
            }
            npc.programs.instr.execute(self, npc.programs.instr.default.PUT_ITEM, args)
            -- Put the item that we want to cook on the furnace
            args = {
                player = nil,
                pos = pos,
                inv_list = "src",
                item_name = npc.get_item_name(src_item.item_string),
                count = npc.get_item_count(item),
                is_furnace = true
            }
            npc.exec.proc.enqueue(self, npc.programs.instr.default.PUT_ITEM, args)

            -- Now, set NPC to wait until furnace is done.
            npc.log("DEBUG", "Setting wait command for "..dump(total_cook_time))
            npc.exec.proc.enqueue(self, npc.programs.instr.default.SET_INTERVAL, {interval=total_cook_time, freeze=freeze})

            -- Reset timer
            npc.exec.proc.enqueue(self, npc.programs.instr.default.SET_INTERVAL, {interval=1, freeze=true})

            -- If freeze is false, then we will have to find the way back to the furnace
            -- once cooking is done.
            if freeze == false then
                npc.log("DEBUG", "Adding walk to position to wandering: "..dump(pos))
                npc.exec.proc.enqueue(self, npc.programs.instr.default.INTERRUPT, {
                    new_program = "advanced_npc:walk_to_pos",
                    new_args = {end_pos=pos, walkable={}},
                    {}
                })
                --npc.enqueue_script(self, npc.programs.instr.default.WALK_TO_POS, {end_pos=pos, walkable={}})
            end

            -- Take cooked items back
            args = {
                player = nil,
                pos = pos,
                inv_list = "dst",
                item_name = cook_result.item:get_name(),
                count = npc.get_item_count(item),
                is_furnace = false
            }
            npc.log("DEBUG", "Taking item back: "..minetest.pos_to_string(pos))
            npc.exec.proc.enqueue(self, npc.programs.instr.default.TAKE_ITEM, args)

            npc.log("DEBUG", "Inventory: "..dump(self.inventory))

            -- Set furnace as unused if flag is enabled
            if enable_usage_marking then
                -- Set place as used
                npc.locations.mark_place_used(pos, npc.locations.USE_STATE.NOT_USED)
            end

            return true
        end
    end
    -- Couldn't use the furnace due to lack of items
    return false
end)


