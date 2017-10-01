----------------------------------------------------
-- Test farmer occupation for Advanced NPC
-- By Zorman2000
----------------------------------------------------
-- This farmer implementation is still WIP. It is supposed to spawn
-- on buildings that have plots or there are fields nearby. Also, it
-- work on its crops during the morning, and sell some of them on the
-- afternoon.

local dugNodeData = npc.getFacingNodeInfo(self, 3)
local dugPosition = dugNodeData[1]
local dugNodeName = dugNodeData[2]
local dugNodeNickname = dugNodeData[3] 
local farmer_def = {
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
                min_count = 5,
                max_count = 10,
                nodes = {"farming:cotton_8"},
                actions =
                {
                    -- Actions for grown cotton - harvest and replant
                    ["farming:cotton_8"] =
                    {
                        [1] =
                        {
                            action = npc.actions.cmd.WALK_TO_POS,
                            args = {
                                node = "farming:cotton_8",
                                walkable = {}
                            }
                        },
                        [2] =
                        {
                            action = npc.actions.cmd.DIG,
                            args = {
                                node = "farming:cotton_8",
                                walkable = {}
                            }
                        },
                        [3] =
                        {
                            if dugNodeNickname == "farming:cotton_8" then
                                action = npc.actions.cmd.PLACE
                                args = {node = "farming:seed_cotton 1"}
                            end
                        }
                    }

                },
                [3] =
                {
                    check = true,
                    range = 3,
                    random_execution_times = true,
                    min_count = 1,
                    max_count = 16,
                    nodes = {"farming:wheat_8"},
                    actions =
                    {
                        ["farming:wheat_8"] =
                        {
                            [1] =
                            {
                                action = npc.actions.cmd.WALK_TO_POS,
                                args = {
                                    node = "farming:wheat_8",
                                    walkable = {}
                                }
                            },
                            [2] =
                            {
                                action = npc.actions.cmd.DIG,
                                args = {
                                    node = "farming:wheat_8",
                                    walkable = {}
                                }
                            },
                            [3] =
                            {
                                if dugNodeNickname == "farming:wheat_8" then
                                    action = npc.actions.cmd.PLACE,
                                    args = {node = "farming:seed_wheat 1"}
                                end
                            }
                       }
                  },
                none_actions = {
                    -- Walk a single step in a random direction
                        action = npc.actions.cmd.WALK_STEP,
                        args = {
                            dir = "random"
                        }
                }
            }
        }
    }
}

-- Register occupation
npc.occupations.register_occupation("default_farmer", farmer_def)
