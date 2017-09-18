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
                min_count = 20,
                max_count = 25,
                nodes = farming_plants.cotton,
                prefer_last_acted_upon_node = true,
                walkable_nodes = farming_plants.cotton,
                actions =
                {
                    -- Actions for cotton - harvest and replant
                    ["farming:cotton_1"] =
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
                                node = "farming:cotton_2",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_2"] =
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
                                node = "farming:cotton_3",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
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
                                node = "farming:cotton_4",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_4"] =
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
                                node = "farming:cotton_5",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_5"] =
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
                                node = "farming:cotton_6",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_6"] =
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
                                node = "farming:cotton_7",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_7"] =
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
                                node = "farming:cotton_8",
                                bypass_protection = true
                            }
                        },
                        [5] =
                        {
                            action = npc.actions.cmd.STAND,
                            args = {}
                        }
                    },
                    ["farming:cotton_8"] =
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
                [3] =
                {
                    check = true,
                    range = 3,
                    random_execution_times = true,
                    min_count = 8,
                    max_count = 8,
                    nodes = {"farming:wheat_8"},
                    actions =
                    {
                        ["farming:wheat_8"] =
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
                                    node = "farming:wheat_1"
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
npc.occupations.register_occupation("farmer", farmer_def)
