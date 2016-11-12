
if not minetest.get_modpath("shop") then
	minetest.register_alias("shop:coin", "default:gold_ingot")
end

local S = mobs.intllib

mobs.human = {
	items = {
		-- item, price, chance
		{"default:apple 10", "shop:coin 2", 40},
		{"farming:bread 10", "shop:coin 4", 50},
		{"default:clay 10", "shop:coin 2", 14},
		{"default:brick 10", "shop:coin 4", 17},
		{"default:glass 10", "shop:coin 4", 17},
		{"default:obsidian 10", "shop:coin 15", 50},
		{"default:diamond 1", "default:goldblock 1", 7},
		{"default:goldblock 1", "default:diamond 1", 7},
		{"farming:wheat 10", "shop:coin 2", 17},
		{"default:tree 5", "shop:coin 4", 20},
		{"default:stone 10", "shop:coin 8", 17},
		{"default:desert_stone 10", "shop:coin 8", 27},
		{"default:sapling 1", "shop:coin 1", 7},
		{"default:pick_steel 1", "shop:coin 2", 7},
		{"default:sword_steel 1", "shop:coin 2", 17},
		{"default:shovel_steel 1", "shop:coin 1", 17},
	},
	names = {
		"Bob", "Duncan", "Bill", "Tom", "James", "Ian", "Lenny"
	}
}

-- Trader ( same as NPC but with right-click shop )

mobs:register_mob("mobs_npc:trader", {
	type = "npc",
	passive = false,
	damage = 3,
	attack_type = "dogfight",
	attacks_monsters = true,
	pathfinding = false,
	hp_min = 10,
	hp_max = 20,
	armor = 100,
	collisionbox = {-0.35,-1.0,-0.35, 0.35,0.8,0.35},
	visual = "mesh",
	mesh = "character.b3d",
	textures = {
		{"mobs_trader.png"}, -- by Frerin
		{"mobs_trader2.png"}, -- re-coloured by amhadinger
		{"mobs_trader3.png"}, -- re-coloured by amhadinger
	},
	makes_footstep_sound = true,
	sounds = {},
	walk_velocity = 2,
	run_velocity = 3,
	jump = false,
	drops = {},
	water_damage = 0,
	lava_damage = 4,
	light_damage = 0,
	follow = {"default:diamond"},
	view_range = 15,
	owner = "",
	order = "stand",
	fear_height = 3,
	animation = {
		speed_normal = 30,
		speed_run = 30,
		stand_start = 0,
		stand_end = 79,
		walk_start = 168,
		walk_end = 187,
		run_start = 168,
		run_end = 187,
		punch_start = 200,
		punch_end = 219,
	},
	on_rightclick = function(self, clicker)
		mobs_trader(self, clicker, mobs.human)
	end,
})

--This code comes almost exclusively from the trader and inventory of mobf, by Sapier.
--The copyright notice below is from mobf:
-------------------------------------------------------------------------------
-- Mob Framework Mod by Sapier
--
-- You may copy, use, modify or do nearly anything except removing this
-- copyright notice.
-- And of course you are NOT allow to pretend you have written it.
--
--! @file inventory.lua
--! @brief component containing mob inventory related functions
--! @copyright Sapier
--! @author Sapier
--! @date 2013-01-02
--
--! @defgroup Inventory Inventory subcomponent
--! @brief Component handling mob inventory
--! @ingroup framework_int
--! @{
--
-- Contact sapier a t gmx net
-------------------------------------------------------------------------------

-- Modifications Copyright 2016 by James Stevenson

local trader_inventory = {}

local function add_goods(race)
	local goods_to_add = nil
	for i = 1, 16 do
		if math.random(0, 100) > race.items[i][3] then
			trader_inventory.set_stack(trader_inventory,
					"goods", i, race.items[i][1])
		end
	end
end

function mobs_trader(self, clicker, race)
	local player = clicker:get_player_name()

	if not self.id then
		self.id = (math.random(1, 1000) * math.random(1, 10000))
			.. self.name .. (math.random(1, 1000) ^ 2)
	end

	if not self.game_name then
		self.game_name = tostring(race.names[math.random(1, #race.names)])
		self.nametag = S("Trader @1", self.game_name)
		self.object:set_properties({
			nametag = self.nametag,
			nametag_color = "#00FF00"
		})
	end

	local unique_entity_id = self.id
	local is_inventory = minetest.get_inventory({
			type = "detached", name = unique_entity_id})

	local move_put_take = {
		allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			if (from_list == "goods" and
					to_list == "selection") or
							(from_list == "selection" and
									to_list == "goods") then
				return count
			else
				return 0
			end
		end,
		allow_put = function(inv, listname, index, stack, player)
			return 0
		end,
		allow_take = function(inv, listname, index, stack, player)
			return 0
		end,
		on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			if from_list == "goods" and
					to_list == "selection" then
				local moved = inv.get_stack(inv, to_list, to_index)
				local goodname = moved.get_name(moved)
				local elements = moved.get_count(moved)
				if elements > count then
					-- Remove the surplus parts
					inv.set_stack(inv, "selection", 1,
							goodname .. " " .. tostring(count))

					-- The slot we took from is now free.
					inv.set_stack(inv, "goods", from_index,
							goodname .. " " .. tostring(elements - count))

					-- Update the real amount of items in the slot now.
					elements = count
				end
				local good = nil
				for i = 1, #race.items, 1 do
					local stackstring = goodname .. " " .. count
					if race.items[i][1] == stackstring then
						good = race.items[i]
					end
				end
				if good ~= nil then
					inv.set_stack(inv, "price", 1, good[2])
				else
					inv.set_stack(inv, "price", 1, nil)
				end
			elseif from_list == "selection" and
					to_list == "goods" then
				inv.set_stack(inv, "price", 1, nil)
			end
		end,
		on_put = function(inv, listname, index, stack, player)
		end,
		on_take = function(inv, listname, index, stack, player)
		end,
	}

	if is_inventory == nil then
		trader_inventory = minetest.create_detached_inventory(unique_entity_id, move_put_take)
		trader_inventory.set_size(trader_inventory, "goods", 16)
		trader_inventory.set_size(trader_inventory, "selection", 1)
		trader_inventory.set_size(trader_inventory, "price", 1)
		add_goods(race)
		--print("added stuff")
	end

	minetest.chat_send_player(player, S("[NPC] <Trader @1> Hello, @2, have a look at my wares.",
			self.game_name, player))

	minetest.show_formspec(player, "mobs_npc:trader", "size[8,9]" ..
			default.gui_bg ..
			default.gui_bg_img ..
			default.gui_slots ..
			"list[detached:" .. unique_entity_id .. ";goods;0,0;8,2]" ..
			"label[0,3;Selection]" ..
			"list[detached:" .. unique_entity_id .. ";selection;2,3;1,1]" ..
			"label[4,3;Price]" ..
			"list[detached:" .. unique_entity_id .. ";price;6,3;1,1]" ..
			"button[4,4;2,1;purchase;Purchase]" ..
			"list[current_player;main;0,5;8,1;]" ..
			"list[current_player;main;0,6.25;8,3;8]" ..
			default.get_hotbar_bg(0, 5))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "mobs_npc:trader" then
		return
	end

	--print(dump(trader_inventory:get_lists()))

	local selection_name = trader_inventory:get_stack("selection", 1):get_name()
	local selection_count = trader_inventory:get_stack("selection", 1):get_count()
	local selection_string = selection_name .. " " .. tostring(selection_count)

	local price_name = trader_inventory:get_stack("price", 1):get_name()
	local price_count = trader_inventory:get_stack("price", 1):get_count()
	local price_string = price_name .. " " .. tostring(price_count)

	--print(selection_string .. "\nfor:\n" .. price_string)

	if player:get_inventory():contains_item("main", price_string) then
		--print("you got it!")
		trader_inventory:set_stack("selection", 1, nil)
		trader_inventory:set_stack("price", 1, nil)

		player:get_inventory():remove_item("main", price_string)
		local adder = player:get_inventory():add_item("main", selection_string)
		if adder then
			minetest.add_item(player:getpos(), adder)
		end
	else
		minetest.chat_send_player(player:get_player_name(),
				"Not enough credits!")
	end

end)

mobs:register_egg("mobs_npc:trader", S("Trader"), "default_sandstone.png", 1)

-- compatibility
mobs:alias_mob("mobs:trader", "mobs_npc:trader")
