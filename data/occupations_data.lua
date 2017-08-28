-- Occupations definitions

-- Register default occupation
npc.occupations.register_occupation("default_basic", npc.occupations.basic_def)

-- Test priest
npc.occupations.register_occupation("test_priest", {
	dialogues = {
		{
			text = "How are you today my child?",
			tags = "male"
		}
	},
	textures = {
		"npc_male_priest.png"
	},
	initial_inventory = {
		"farming:bread 1"
	},
	building_types = {
		"home"
	},
	surrounding_building_types = {
		"church"
	},
	schedule_entries = {}
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