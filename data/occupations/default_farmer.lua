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
                            action = npc.actions.cmd.WALK_TO_POS,
                            args = {
                                node = "farming:cotton_3",
                                walkable = true
                            }
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
                [3] =
                {
                    check = true,
                    range = 3,
                    random_execution_times = true,
                    min_count = 16,
                    max_count = 96,
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
                                    walkable = true
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
                            dir = "random"
                        }
                    }
                }
            }
        }
    }
}

-- Register occupation
npc.occupations.register_occupation("default_farmer", farmer_def)
