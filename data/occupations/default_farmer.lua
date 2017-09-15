----------------------------------------------------
-- Test farmer occupation for Advanced NPC
-- By Zorman2000
----------------------------------------------------
-- This farmer implementation is still WIP. It is supposed to spawn
-- on buildings that have plots or there are fields nearby. Also, it
-- work on its crops during the morning, and sell some of them on the
-- afternoon.

local farming_plants = {
    cotton = {
        "farming:cotton_1",
        "farming:cotton_2",
        "farming:cotton_3",
        "farming:cotton_4",
        "farming:cotton_5",
        "farming:cotton_6",
        "farming:cotton_7",
        "farming:cotton_8"
    }
}

local farmer_def = {
    dialogues = {},
    textures = {},
    building_types = {
        "farm_tiny", "farm_full"
    },
    surrounding_building_types = {
        {type="field", origin_building_types={"hut", "house", "lumberjack"}}
    },
    walkable_nodes = farming_plants.cotton,
    initial_inventory = {},
    schedules_entries = {
        [7] = {
            [1] =
            {
                task = npc.actions.cmd.WALK_TO_POS,
                args = {
                    end_pos = npc.places.PLACE_TYPE.WORKPLACE.PRIMARY,
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
                walkable_nodes = farming_plants.cotton,
                actions =
                {
                    -- Actions for cotton - harvest and replant
                    ["farming:cotton_3"] =
                    {
                        [1] =
                        {
                            task = npc.actions.cmd.WALK_TO_POS,
                            args = {
                                end_pos = npc.places.PLACE_TYPE.SCHEDULE.TARGET,
                                walkable = farming_plants.cotton
                            }
                        },
                        [2] =
                        {
                            action = npc.actions.cmd.DIG,
                            args = {
                                bypass_protection = true
                            }
                        },
                        [3] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        },
                        [4] =
                        {
                            action = npc.actions.cmd.PLACE,
                            args =
                            {
                                node = "farming:cotton_1",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
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
                            dir = "random_orthogonal"
                        }
                    },
                    [2] = {
                        action = npc.actions.cmd.STAND,
                        args = {}
                    }
                }
            }
        }
    }
}

-- Register occupation
npc.occupations.register_occupation("test_farmer", farmer_def)