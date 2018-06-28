-- Occupations/jobs functionality by Zorman2000
-----------------------------------------------
-- Occupations functionality
-- NPCs need an occupation or job in order to simulate being alive.
-- This functionality is built on top of the schedules functionality.
-- Occupations are essentially specific schedules, that can have slight
-- random variations to provide diversity and make specific occupations
-- less predictable. Occupations are associated with textures, dialogues,
-- specific initial items, type of building (and surroundings) where NPC
-- lives, etc.
-- Example of an occupation: farmer
-- The farmer will have to live in a farm, or just beside a field.
-- It will have the following schedule:
-- 6AM  - get out of bed, walk to home inside, goes to chest, retrieves
--        seeds and wander
-- 7AM  - goes out to the field and randomly start harvesting and planting
--        crops that are already fully grown
-- 12PM - gets a random but moderate (5-15) amount of seeds and harvested
--      - crops. Goes into the house, stores 1/4 of the amount in a chest,
--      - gets all currency items it has, and sits into a bench
-- 1PM  - goes outside the house and becomes trader, sells the remaining
--      - seeds and crops
-- 6PM  - goes inside the house. Stores all currency items it has, all
--      - remainin seeds and crops, and sits on a bench
-- 8PM  - gets out of the bench, wanders inside home
-- 10PM - goes to bed

-- Implementation:
-- A function, npc.register_occupation(), will be provided to register an
-- occupation that can be used to initialize NPCs. The format is the following:
-- {
--		dialogues = {
--			enable_gift_item_dialogues = true,
--				-- This flag enables/disables gift item dialogues.
--				-- If not set, it defaults to true.
--			type = "",
--				-- The type can be "given", "mix" or "tags"
--			data = {},
--				-- Array of dialogue definitions. This will have dialogue
--				-- if the type is either "mix" or "given"
--			tags = {},
--				-- Array of tags to search for. This will have tags
--				-- if the type is either "mix" or "tags"
--
--		},
--		textures = {},
--			-- Textures are an array of textures, as usually given on
-- 			-- an entity definition. If given, the NPC will be guaranteed
--			-- to have one of the given textures. Also, ensure they have gender
--			-- as well in the filename so they can be chosen appropriately.
--			-- If left empty, it can spawn with any texture.
--		building_types = {},
--			-- An array of string where each string is the type of building
--			-- where the NPC can spawn with this occupation.
--			-- Example: building_type = {"farm", "house"}
--			-- If left empty or nil, NPC can spawn in any building
--		surrounding_building_types = {},
--			-- An array of string where each string is the type of building
--			-- that is an immediate neighbor of the NPC's home which can also
--			-- be suitable for this occupation. Example, if NPC is farmer and
--			-- spawns on house, then it has to be because there is a field
--			-- nearby. If left empty or nil, surrounding buildings doesn't
--			-- matter
--		workplace_nodes = {},
--			-- An array of string where each string is a node the NPC
--			-- works with. These are useful for assigning workplaces and work
--			-- work nodes.
--		initial_inventory = {},
--			-- An array of entries like the following:
--			-- {name="", count=1} -- or
--			-- {name="", random=true, min=1, max=10}
--			-- This will initialize the inventory for the NPC with the given
--			-- items and the specified count, or, a count between min and max
--			-- when the entry contains random=true
--			-- If left empty, it will initialize with random items.
--		initial_trader_status = "",
--			-- String that specifies initial trader value. Valid values are:
--			-- "casual", "trader", "none"
--		schedules_entries = {},
--			-- This is a table of tables in the following format:
--			-- {
--				[1]  = {[1] = action = npc.action.cmd.freeze, args={freeze=true}},
--				[13] = {[1] = action = npc.action.cmd.freeze, args={freeze=false},
--						[2] = action = npc.action.cmd.freeze, args={freeze=true}
--						},
--				[23] = {[1] = action=npc.action.cmd.freeze, args={freeze=false}}
--			-- }
-- 			-- The numbers, [1], [13] and [23] are the times when the entries
--			-- corresponding to each are supposed to happen. The tables with
--			-- [1], [1],[2] and [1] actions respectively are the entries that
--			-- will happen at time 1, 13 and 23.
-- }

-- Public API
npc.occupations = {}

-- Private API
local occupations = {}

-- This array contains all the registered occupations.
-- The key is the name of the occupation.
npc.occupations.registered_occupations = {}

-- Basic occupation name
npc.occupations.basic_name = "default_basic"

-- This is the basic occupation definition, this is for all NPCs that
-- don't have a specific occupation. It serves as an example.
npc.occupations.basic_def = {
	-- Use random textures
	textures = {},
	-- Use random dialogues
	dialogues = {},
	-- Initialize inventory with random items
	initial_inventory = {},
	-- Initialize schedule
	schedules_entries = {
		-- Schedule entry for 7 in the morning
--		[7] = {
--			-- Get out of bed
--			[1] = {task = npc.commands.cmd.USE_BED, args = {
--				pos = npc.locations.data.bed.primary,
--				action = npc.commands.const.beds.GET_UP
--			}
--			},
--			-- Walk to home inside
--			[2] = {task = npc.commands.cmd.WALK_TO_POS, args = {
--				end_pos = npc.locations.data.OTHER.HOME_INSIDE,
--				walkable = {}
--			},
--				chance = 75
--			},
--			-- Allow mobs_redo wandering
--			[3] = {action = npc.commands.cmd.FREEZE, args = {freeze = false}}
--		},
--		-- Schedule entry for 7 in the morning
--		[8] = {
--			-- Walk to outside of home
--			[1] = {task = npc.commands.cmd.WALK_TO_POS, args = {
--				end_pos = npc.locations.data.OTHER.HOME_OUTSIDE,
--				walkable = {}
--			},
--				chance = 75
--			},
--			-- Allow mobs_redo wandering
--			[2] = {action = npc.commands.cmd.FREEZE, args = {freeze = false}}
--		},
--		-- Schedule entry for 12 midday
--		[12] = {
--			-- Walk to a sittable node
--			[1] = {task = npc.commands.cmd.WALK_TO_POS, args = {
--				end_pos = {place_type=npc.locations.data.SITTABLE.PRIMARY, use_access_node=true},
--				walkable = {"cottages:bench"}
--			},
--				chance = 75
--			},
--			-- Sit on the node
--			[2] = {task = npc.commands.cmd.USE_SITTABLE, args = {
--				pos = npc.locations.data.SITTABLE.PRIMARY,
--				action = npc.commands.const.sittable.SIT
--			},
--				depends = {1}
--			},
--			-- Stay put into place
--			[3] = {action = npc.commands.cmd.SET_INTERVAL, args = {
--				freeze = true,
--				interval = 35
--			},
--				depends = {2}
--			},
--			[4] = {action = npc.commands.cmd.SET_INTERVAL, args = {
--				freeze = true,
--				interval = npc.commands.default_interval
--			},
--				depends = {3}
--			},
--			-- Get up from sit
--			[5] = {action = npc.commands.cmd.USE_SITTABLE, args = {
--				pos = npc.locations.data.SITTABLE.PRIMARY,
--				action = npc.commands.const.sittable.GET_UP
--			},
--				depends = {4}
--			}
--		},
--		-- Schedule entry for 1 in the afternoon
--		[13] = {
--			-- Give NPC money to buy from player
--			[1] = {property = npc.schedule_properties.put_multiple_items, args = {
--				itemlist = {
--					{name="default:iron_lump", random=true, min=2, max=4}
--				}
--			},
--				chance = 75
--			},
--			-- Change trader status to "trader"
--			[2] = {property = npc.schedule_properties.trader_status, args = {
--				status = npc.trade.TRADER
--			},
--				chance = 75
--			},
--			[3] = {property = npc.schedule_properties.can_receive_gifts, args = {
--				can_receive_gifts = false
--			},
--				depends = {1}
--			},
--			-- Allow mobs_redo wandering
--			[4] = {action = npc.commands.cmd.FREEZE, args = {freeze = false}}
--		},
--		-- Schedule entry for 6 in the evening
--		[18] = {
--			-- Change trader status to "none"
--			[1] = {property = npc.schedule_properties.trader_status, args = {
--				status = npc.trade.NONE
--			}
--			},
--			-- Enable gift receiving again
--			[2] = {property = npc.schedule_properties.can_receive_gifts, args = {
--				can_receive_gifts = true
--			}
--			},
--			-- Get inside home
--			[3] = {task = npc.commands.cmd.WALK_TO_POS, args = {
--				end_pos = npc.locations.data.OTHER.HOME_INSIDE,
--				walkable = {}
--			}
--			},
--			-- Allow mobs_redo wandering
--			[4] = {action = npc.commands.cmd.FREEZE, args = {freeze = false}}
--		},
--		-- Schedule entry for 10 in the evening
--		[22] = {
--			[1] = {task = npc.commands.cmd.WALK_TO_POS, args = {
--				end_pos = {place_type=npc.locations.data.bed.primary, use_access_node=true},
--				walkable = {}
--			}
--			},
--			-- Use bed
--			[2] = {task = npc.commands.cmd.USE_BED, args = {
--				pos = npc.locations.data.bed.primary,
--				action = npc.commands.const.beds.LAY
--			}
--			},
--			-- Stay put on bed
--			[3] = {action = npc.commands.cmd.FREEZE, args = {freeze = true}}
--		}
	}
}


-- This function registers an occupation
function npc.occupations.register_occupation(name, def)
	-- Register all textures per definition
	if def.textures and next(def.textures) ~= nil then
		-- These are in the format: {name="", tags={"tag1","tag2", ...}}
		for i = 1, #def.textures do
			npc.info.register_texture(def.textures[i].name, def.textures[i].tags)
		end
	end

	-- Register all dialogues per definition
	local dialogue_keys = {}
	if def.dialogues then
		-- Check which type of dialogues we have
		if def.dialogues.type == "given" then
			-- We have been given the dialogues, so def.dialogues.data contains
			-- an array of dialogues
			for _, dialogue in pairs(def.dialogues.data) do
				-- Add to the dialogue tags the "occupation name"
				table.insert(dialogue.tags, name)
				-- Register dialogue
				npc.log("INFO", "Registering dialogue for occupation "..dump(name)..": "..dump(dialogue))
				local key = npc.dialogue.register_dialogue(dialogue)
				-- Add key to set of dialogue keys
				table.insert(dialogue_keys, key)
			end
		elseif def.dialogues.type == "mix" then
			-- We have been given the dialogues, so def.dialogues.data contains
			-- an array of dialogues and def.dialogues.tags contains an array of
			-- tags. Currently only registering will be performed.
			-- Register dialogues
			for _, dialogue in pairs(def.dialogues.data) do
				-- Add to the dialogue tags the "occupation name"
				table.insert(dialogue.tags, name)
				-- Register dialogue
				local key = npc.dialogue.register_dialogue(dialogue)
				-- Add key to set of dialogue keys
				table.insert(dialogue_keys, key)
			end
		end
	end

	-- Save into the definition the dialogue keys
	def.dialogues["keys"] = dialogue_keys

	-- Validate state program
	if def.state_program then
		if npc.programs.is_registered(def.state_program.name) == false then
			npc.log("ERROR", "Unable to find program with name: "..dump(def.state_program.name))
			return
		end
	end

	-- Save the definition
	npc.occupations.registered_occupations[name] = def

	npc.log("INFO", "Successfully registered occupation with name: "..dump(name))
end

-- This function scans all registered occupations and filter them by
-- building type and surrounding building type, returning an array
-- of occupation names (strings)
-- BEWARE! Below this lines lies ugly, incomprehensible code!
function npc.occupations.get_for_building(building_type, surrounding_building_types)
	local result = {}
	for name,def in pairs(npc.occupations.registered_occupations) do
		-- Check for empty or nil building types, in that case, any building
		if def.building_types == nil or def.building_types == {}
				and def.surrounding_building_types == nil or def.surrounding_building_types == {} then
			-- Empty building types, add to result
			table.insert(result, name)
		elseif def.building_types ~= nil and #def.building_types > 0 then
			-- Check if building type is contained in the def's building types
			if npc.utils.array_contains(def.building_types, building_type) then
				table.insert(result, name)
			end
		end
		-- Check for empty or nil surrounding building types
		if def.surrounding_building_types ~= nil
				and #def.surrounding_building_types > 0 then
--			-- Add this occupation
--			--table.insert(result, name)
--		else
			-- Surrounding buildings is not empty, loop though them and compare
			-- to the given ones
			for i = 1, #surrounding_building_types do
				for j = 1, #def.surrounding_building_types do
					-- Check if the definition's surrounding building type is the same
					-- as the given one
					if def.surrounding_building_types[j].type
							== surrounding_building_types[i].type then
						-- Check if the origin buildings contain the expected type
						if npc.utils.array_contains(def.surrounding_building_types[j].origin_building_types,
							surrounding_building_types[i].origin_building_type) then
							-- Add this occupation
							table.insert(result, name)
						end
					end
				end
			end
		end
	end
	return result
end

-- This function will initialize entities values related to
-- the occupation: textures, dialogues, inventory items and
-- will set schedules accordingly.
function npc.occupations.initialize_occupation_values(self, occupation_name)
	-- Get occupation definition
	local def = npc.occupations.registered_occupations[occupation_name]

	if not def then
		npc.log("WARNING", "No definition found for occupation name: "..dump(occupation_name))
		return
	end

	npc.log("INFO", "Overriding NPC values using occupation '"..dump(occupation_name).."' values")

	-- Initialize textures, else it will leave the current textures
	-- Pick them from tags
	if def.textures and table.getn(def.textures) > 0 then
		-- Select a texture
		local available_textures = npc.info.get_textures({self.gender, self.age, occupation_name}, "all_match")

		-- Set texture if it found for gender and age
		-- If an array was returned, select a random texture from it
		if next(available_textures) ~= nil then
			self.selected_texture = available_textures[math.random(1, #available_textures)]
		end
	else
		-- Try to choose a random texture - if exists
		if next(npc.info.textures) ~= nil then
			local available_textures = npc.info.get_textures({self.gender, self.age}, "all_match")
			self.selected_texture = available_textures[math.random(1, #available_textures)]
		else
			-- Return a default texture
			self.selected_texture = "default_"..self.gender..".png"
		end
	end
	minetest.log("Result: "..dump(self.selected_texture))

	-- Set texture and base texture
	self.textures = {self.selected_texture}
	self.base_texture = {self.selected_texture}
	-- Refresh entity
	self.object:set_properties(self)

	-- Initialize inventory
	if def.initial_inventory and table.getn(def.initial_inventory) > 0 then
		for i = 1, #def.initial_inventory do
			local item = def.initial_inventory[i]
			-- Check if item count is randomized
			if item.random and item.min and item.max then
				npc.add_item_to_inventory(self, item.name, math.random(item.min, item.max))
			else
				-- Add item with the given count
				npc.add_item_to_inventory(self, item.name, item.count)
			end
		end
	end

	-- Initialize dialogues
	if def.dialogues then
		-- Check for gift item dialogues enable
		if def.dialogues.disable_gift_item_dialogues then
			self.dialogues.hints = {}
		end

		local dialogue_keys = {}
		-- Check which type of dialogues we have
		if def.dialogues.type == "given" and def.dialogues.keys then
			-- We have been given the dialogues, so def.dialogues.data contains
			-- an array of dialogues. These dialogues were registered, therefore we need
			-- just the keys
			for i = 1, #def.dialogues.keys do
				table.insert(dialogue_keys, def.dialogues.keys[i])
			end
		elseif def.dialogues.type == "mix" then
			-- We have been given the dialogues, so def.dialogues.data contains
			-- an array of dialogues and def.dialogues.tags contains an array of
			-- tags that we will use to search
			if def.dialogues.keys then
				-- Add the registered dialogues
				for i = 1, #def.dialogues.keys do
					table.insert(dialogue_keys, def.dialogues.keys[i])
				end
			end
			-- Find dialogues using tags
			local dialogues = npc.dialogue.search_dialogue_by_tags(def.dialogues.tags, true)
			-- Add keys to set of dialogue keys
			for _, key in pairs(npc.utils.get_map_keys(dialogues)) do
				table.insert(dialogue_keys, key)
			end
		elseif def.dialogues.type == "tags" then
			-- We need to find the dialogues from tags. def.dialogues.tags contains
			-- an array of tags that we will use to search.
			local dialogues = npc.dialogue.search_dialogue_by_tags(def.dialogues.tags, true)
			-- Add keys to set of dialogue keys
			dialogue_keys = npc.utils.get_map_keys(dialogues)
		end
		-- Add dialogues to NPC
		-- Check if there is a max of dialogues to be added
		local max_dialogue_count = npc.dialogue.MAX_DIALOGUES
		if def.dialogues.max_count and def.dialogues.max_count > 0 then
			max_dialogue_count = def.dialogues.max_count
		end
		-- Add dialogues to the normal dialogues for NPC
		if #dialogue_keys > 0 then
			self.dialogues.normal = {}
			for i = 1, math.min(max_dialogue_count, #dialogue_keys) do
				self.dialogues.normal[i] = dialogue_keys[i]
			end
		end
	end

	-- Initialize properties
	minetest.log("def.properties: "..dump(def.properties))
	if def.properties then
		-- Initialize trader status
		if def.properties.initial_trader_status then
			self.trader_data.trader_status = def.properties.initial_trader_status
		end
		-- Enable/disable gift items hints
		if def.properties.enable_gift_items_hints ~= nil then
			self.gift_data.enable_gift_items_hints = def.properties.enable_gift_items_hints
		end
	end

	-- Initialize state program
	if def.state_program then
		npc.exec.set_state_program(self,
			def.state_program.name,
			def.state_program.args,
			def.state_program.interrupt_options)
		npc.log("INFO", "Successfully set state program "..dump(def.state_program.name))
	end

	-- Initialize schedule entries
	if def.schedules_entries and table.getn(npc.utils.get_map_keys(def.schedules_entries)) > 0 then
		-- Create schedule in NPC
		npc.schedule.create(self, npc.schedule.const.types.generic, 0)
		-- Traverse schedules
		for time, entries in pairs(def.schedules_entries) do
			-- Add schedule entry for each time
			npc.schedule.entry.put(self, npc.schedule.const.types.generic, 0, time, nil, entries)
		end
	end

	npc.log("INFO", "Successfully initialized NPC with occupation values")

end
