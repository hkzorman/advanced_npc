----------------------------------------------------
-- Default occupation for Advanced NPC
-- By Zorman2000
----------------------------------------------------
-- The default "occupation" gives some schedule entries to the NPCs
-- which don't have any occupation. The rest is left as randomly
-- initialized.

local basic_def = {
    -- Use random textures
    textures = {},
    -- Use random dialogues
    dialogues = {},
    -- Initialize inventory with random items
    initial_inventory = {},
    -- Initialize schedule
    schedules_entries = {
        -- Schedule entry for 7 in the morning
        [7] = {
            -- Change trader status to "none"
            [1] = {
                property = npc.schedule_properties.trader_status,
                args = {
                    status = npc.trade.NONE
                }
            },
            -- Get out of bed
            [1] = {task = npc.actions.cmd.USE_BED, args = {
                pos = npc.places.PLACE_TYPE.BED.PRIMARY,
                action = npc.actions.const.beds.GET_UP
            }
            },
            -- Walk to home inside
            [2] = {
                task = npc.actions.cmd.WALK_TO_POS,
                args = {
                    end_pos = npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
                    walkable = {}
                },
                chance = 75
            },
            -- Allow mobs_redo wandering
            [3] = {action = npc.actions.cmd.FREEZE, args = {freeze = false, disable_rightclick = false}}
        },
        -- Schedule entry for 8 in the morning
        [8] = {
            -- Walk to outside of home
            [1] = {task = npc.actions.cmd.WALK_TO_POS, args = {
                end_pos = npc.places.PLACE_TYPE.OTHER.HOME_OUTSIDE,
                walkable = {}
            },
                chance = 75
            },
            -- Allow mobs_redo wandering
            [2] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
        },
        -- Schedule entry for 12 midday
        [12] = {
            -- Walk to a sittable node
            [1] = {task = npc.actions.cmd.WALK_TO_POS,
                args = {
                    end_pos = {
                        place_category=npc.places.PLACE_TYPE.CATEGORIES.SITTABLE,
                        place_type=npc.places.PLACE_TYPE.SITTABLE.PRIMARY,
                        use_access_node=true,
                        try_alternative_if_used=true,
                        mark_target_as_used = true
                    },
                    walkable = {"cottages:bench"}
                },
                chance = 75
            },
            -- Sit on the node
            [2] = {task = npc.actions.cmd.USE_SITTABLE,
                args = {
                    pos = npc.places.PLACE_TYPE.CALCULATED.TARGET,
                    action = npc.actions.const.sittable.SIT
                },
                depends = {1}
            },
            -- Stay put into place
            [3] = {
                action = npc.actions.cmd.FREEZE, args = {freeze = true},
                depends = {2}
            }
        },
        -- Schedule entry for 1 in the afternoon
        [13] = {
            -- Get up from sit
            [1] = {
                action = npc.actions.cmd.USE_SITTABLE, args = {
                    pos = npc.places.PLACE_TYPE.CALCULATED.TARGET,
                    action = npc.actions.const.sittable.GET_UP
                },
            },
            -- Give NPC money to buy from player
            [2] = {
                property = npc.schedule_properties.put_multiple_items,
                args = {
                    itemlist = {
                        {name="default:iron_lump", random=true, min=2, max=4}
                    }
                },
                chance = 75
            },
            -- Change trader status to "casual trader"
            [3] = {
                property = npc.schedule_properties.trader_status,
                args = {
                    status = npc.trade.CASUAL
                },
                chance = 75
            },
            [4] = {
                property = npc.schedule_properties.can_receive_gifts,
                args = {
                    can_receive_gifts = false
                },
                depends = {1}
            },
            -- Allow mobs_redo wandering
            [5] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
        },
        -- Schedule entry for 6 in the evening
        [18] = {
            -- Change trader status to "none"
            [1] = {property = npc.schedule_properties.trader_status, args = {
                status = npc.trade.NONE
            }
            },
            -- Enable gift receiving again
            [2] = {property = npc.schedule_properties.can_receive_gifts, args = {
                can_receive_gifts = true
            }
            },
            -- Get inside home
            [3] = {task = npc.actions.cmd.WALK_TO_POS, args = {
                end_pos = npc.places.PLACE_TYPE.OTHER.HOME_INSIDE,
                walkable = {}
            }
            },
            -- Allow mobs_redo wandering
            [4] = {action = npc.actions.cmd.FREEZE, args = {freeze = false}}
        },
        -- Schedule entry for 10 in the evening
        [22] = {
            [1] = {task = npc.actions.cmd.WALK_TO_POS, args = {
                end_pos = {place_type=npc.places.PLACE_TYPE.BED.PRIMARY, use_access_node=true},
                walkable = {}
            }
            },
            -- Use bed
            [2] = {task = npc.actions.cmd.USE_BED,
                args = {
                    pos = npc.places.PLACE_TYPE.BED.PRIMARY,
                    action = npc.actions.const.beds.LAY
                }
            },
            -- Stay put on bed
            [3] = {action = npc.actions.cmd.FREEZE, args = {freeze = true, disable_rightclick = true}}
        }
    }
}

-- Register default occupation
npc.occupations.register_occupation(npc.occupations.basic_name, basic_def)