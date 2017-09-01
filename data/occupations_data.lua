-- Occupations definitions

-- Register default occupation
npc.occupations.register_occupation(npc.occupations.basic_name, npc.occupations.basic_def)

-- Test priest
npc.occupations.register_occupation("test_priest", {
	dialogues = {
		type = "given",
		data = {
			{
				text = "How are you today my child?",
				tags = {"male"}
			},
			{
				text = "Welcome to the temple, how can I help you today?",
				flag = {name="on_church", value=true},
				tags = {"unisex"},
				responses =
				{
					[1] = {
						text = "I'm injured. Can you heal me?",
						action_type = "function",
						action = function(self, player)
							local heal_count = self.flags["heal_count"]
							if heal_count then
								-- Increase heal count
								self.flags["heal_count"] = self.flags["heal_count"] + 1
							else
								self.flags["heal_count"] = 1
								heal_count = 1
							end
							-- Check if heal count is achieved
							if heal_count > 5 then
								npc.chat(self.npc_name, player:get_player_name(), "I cannot heal you anymore, "
										.."my child. To mortals like you and me, the power of the Creator is "
										.." limited. Only though learning the teachings we are able to understand more"
										.."... Be safe my child.")
							else
								npc.chat(self.npc_name, player:get_player_name(),
									"Receive the blessings of the Creator!")
								effect(self.object:getpos(), 20, "default_coral_skeleton.png", 0.1, 0.3, 3, 10)
								-- Heal one heart
								player:set_hp(player:get_hp() + 2)
							end
						end
					},
					[2] = {
						text = "What are your teachings?",
						action_type = "function",
						action = function(self, player)
							local teachings = {
								[1] = "Do unto others what you would have them do unto you.",
								[2] = "Sincerity is the way to heaven, and to think how to be sincere is the way of the man",
								[3] = "Even as the scent dwells within the flower, so God within thine own heart forever abides"
							}
							npc.chat(self.npc_name, player:get_player_name(), teachings[math.random(1, #teachings)]
									..". These are the teachings of our Creator.")
						end
					}
				}
			}
		}
	},
	textures = {
		"npc_male_priest.png"
	},
	initial_inventory = {
		{name="farming:bread", count=1}
	},
	initial_trader_status = npc.trade.NONE,
	building_types = {
		"hut", "house", "farm_tiny", "lumberjack"
	},
	surrounding_building_types = {
		"church"
	},
	schedules_entries = {
		[7] = {
			-- Get out of bed
			[1] = {
				task = npc.actions.cmd.USE_BED,
				args = {
					pos = npc.places.PLACE_TYPE.BED.PRIMARY,
					action = npc.actions.const.beds.GET_UP
				}
			},
			-- Walk to home inside
			[2] = {
				task = npc.actions.cmd.WALK_TO_POS,
				chance = 95,
				args = {
					end_pos = npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
					walkable = {}
				}
			},
			-- Allow mobs_redo wandering
			[3] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
		},
		[8] = {
			-- Walk to workplace
			[1] =
			{
				task = npc.actions.cmd.WALK_TO_POS,
				args = {
					end_pos = npc.places.PLACE_TYPE.WORKPLACE.PRIMARY,
					walkable = {},
					use_access_node = true
				}
			},
			[2] =
			{
				property = npc.schedule_properties.flag,
				args = {
					action = "set",
					flag_name = "on_church",
					flag_value = true
				}
			}
		},
		[17] = {
			[1] =
			{
				property = npc.schedule_properties.flag,
				args = {
					action = "set",
					flag_name = "on_church",
					flag_value = false
				}
			},
			[2] =
			{
				task = npc.actions.cmd.WALK_TO_POS,
				args = {
					end_pos = npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
					walkable = {}
				}
			}
		},
		[21] = {
			[1] = {
				task = npc.actions.cmd.WALK_TO_POS,
				args = {
					end_pos = {place_type=npc.places.PLACE_TYPE.BED.PRIMARY, use_access_node=true},
					walkable = {}
				}
			},
			-- Use bed
			[2] = {
				task = npc.actions.cmd.USE_BED,
				args = {
					pos = npc.places.PLACE_TYPE.BED.PRIMARY,
					action = npc.actions.const.beds.LAY
				}
			},
			-- Stay put on bed
			[3] = {action = npc.actions.cmd.FREEZE, args = {freeze = true}}
		}
	}
})

-- Test farmer
npc.occupations.register_occupation("test_farmer", {
	dialogues = {},
	textures = {},
	initial_inventory = {},
	schedule_entries = {
		[7] = {
			[1] =
			{
				task = npc.actions.cmd.WALK_TO_POS,
				args = {
					end_pos = npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE,
					walkable = {}
				}
			},
			[2] =
			{
				check = true,
				range = 2,
				random_execution_times = true,
				min_count = 10,
				max_count = 12,
				nodes = {"farming:cotton_3"},
				actions =
				{
					-- Actions for grown cotton - harvest and replant
					["farming:cotton_3"] =
					{
						[1] =
						{
							action = npc.actions.cmd.WALK_STEP,
						},
						[2] =
						{
							action = npc.actions.cmd.DIG,
						},
						[3] =
						{
							action = npc.actions.cmd.PLACE,
							args =
							{
								node = "farming:cotton_1"
							}
						}
					}

				},
				none_actions =
				{
					-- Walk a single step in a random direction
					[1] = {
						action = npc.actions.cmd.WALK_STEP,
						args =
						{
							dir = "random"
						}
					},
				}
			}
		}
	}
})