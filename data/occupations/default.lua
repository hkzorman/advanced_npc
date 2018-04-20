----------------------------------------------------
-- Default class for Advanced NPC
-- By Zorman2000
----------------------------------------------------
-- The default "class" gives some schedule entries to the NPCs
-- which don't have any occupation. The rest is left as randomly
-- initialized.

local basic_def = {
    -- Use random textures
    textures = {},
    -- Use random dialogues
    dialogues = {
        type = "given",
        max_count = 1,
        data = {
            {
                text = "Hello!",
                tags = {"unisex", "follow"},
                responses = {
                    [1] = {
                        text = "Follow",
                        action_type = "function",
                        action = function(self, player)
                            npc.add_flag(self, "follow_player", true)
                            -- Follow
                            npc.exec.interrupt(self, "advanced_npc:follow", {
                                    target="player",
                                    radius="5",
                                    player_name=player:get_player_name(),
                                    follow_flag="follow_player"
                                },
                                {
                                    allow_scheduler_interruption = false
                                })
                        end
                    },
                    [2] = {
                        text = "Stop following",
                        action_type = "function",
                        action = function(self, player)
                            npc.update_flag(self, "follow_player", false)
                            npc.chat(self.npc_name, player:get_player_name(), "Ok!")
                        end,
                    },
                }
            }
        }
    },
    -- Initialize inventory with random items
    initial_inventory = {},
    -- Initialize default state program
--    state_program = {
--        name = "advanced_npc:idle",
--        args = {
--            acknowledge_nearby_objs = true
--        },
--        interrupt_options = {}
--    },
    state_program = {
        name = "advanced_npc:wander",
        args = {
            acknowledge_nearby_objs = true
        },
        interrupt_options = {}
    },
    -- Initialize schedule
    schedules_entries = {
        -- schedule entry for 7 in the morning
        [7] = {
            [1] = {
                program_name = "advanced_npc:internal_property_change",
                arguments = {
                    property = npc.programs.internal_properties.change_trader_status,
                    args = {
                        status = npc.trade.NONE
                    }
                },
                interrupt_options = {}
            },
            [2] = {
                program_name = "schedules:default:wake_up",
                arguments = {},
                interrupt_options = {}
            },
            -- walk to home inside
            [3] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = npc.locations.data.other.home_inside,
                    walkable = {}
                },
                interrupt_options = {},
                chance = 75
            },
            [4] = {
                program_name = "advanced_npc:idle",
                arguments = {
                    acknowledge_nearby_objs = true
                },
                interrupt_options = {},
                is_state_program = true
            }
        },
        -- schedule entry for 10 in the morning
        [10] = {
            -- walk to outside of home
            [1] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = npc.locations.data.other.home_outside,
                    walkable = {}
                },
                interrupt_options = {},
                chance = 75
            }
        },
        -- schedule entry for 12 midday
        [12] = {
            -- walk to a sittable node
            [1] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = {
                        place_category = npc.locations.data.categories.sittable,
                        place_type = npc.locations.data.sittable.primary,
                        use_access_node = true,
                        try_alternative_if_used = true,
                        mark_target_as_used = true
                    },
                    walkable = {"cottages:bench"}
                },
                chance = 75,
                interrupt_options = {},
            },
            -- sit on the node
            [2] = {
                program_name = "advanced_npc:use_sittable",
                arguments = {
                    pos = npc.locations.data.calculated.target,
                    action = npc.programs.const.node_ops.sittable.SIT
                },
                depends = {1},
                interrupt_options = {}
            },
            -- stay put
            [3] = {
                program_name = "advanced_npc:idle",
                arguments = {
                    acknowledge_nearby_objs = false,
                    wander_chance = 0
                },
                interrupt_options = {},
                is_state_program = true
            }
        },
        -- schedule entry for 1 in the afternoon
        [13] = {
            -- get up from sit
            [1] = {
                program_name = "advanced_npc:use_sittable",
                arguments = {
                    pos = npc.locations.data.calculated.target,
                    action = npc.programs.const.node_ops.sittable.GET_UP
                },
                interrupt_options = {}
            },
            -- give npc money to buy from player
            [2] = {
                program_name = "advanced_npc:internal_property_change",
                arguments = {
                    property = npc.programs.internal_properties.put_multiple_items,
                    args = {
                        itemlist = {
                            {name="default:iron_lump", random=true, min=2, max=4}
                        }
                    },
                },
                interrupt_options = {},
                chance = 75
            },
            -- change trader status to "casual trader"
            [3] = {
                program_name = "advanced_npc:internal_property_change",
                arguments = {
                    property = npc.schedule_properties.change_trader_status,
                    args = {
                        status = npc.trade.CASUAL
                    },
                },
                interrupt_options = {},
                chance = 75
            },
            [4] = {
                program_name = "advanced_npc:internal_property_change",
                arguments = {
                    property = npc.schedule_properties.can_receive_gifts,
                    args = {
                        can_receive_gifts = false
                    },
                },
                interrupt_options = {},
                depends = {3}
            },
        },
        -- schedule entry for 6 in the evening
        [18] = {
            -- change trader status to "none"
            [1] = {
                program_name = "advanced_npc:internal_property_change",
                arguments = {
                    {
                        property = npc.schedule_properties.change_trader_status,
                        args = {
                            status = npc.trade.NONE
                        },
                    },
                    {
                        property = npc.schedule_properties.can_receive_gifts,
                        args = {
                            can_receive_gifts = true
                        },
                    }

                },
                interrupt_options = {},
            },
            -- get inside home
            [2] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = npc.locations.data.other.home_inside,
                    walkable = {}
                },
                interrupt_options = {},
            }
        },
        [21] = {
            [1] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = npc.locations.data.other.room_inside,
                    walkable = {}
                },
                interrupt_options = {}
            }
        },
        -- schedule entry for 10 in the evening
        [22] = {
            [1] = {
                program_name = "advanced_npc:walk_to_pos",
                arguments = {
                    end_pos = {place_type=npc.locations.data.bed.primary, use_access_node=true},
                    walkable = {}
                },
                interrupt_options = {}
            },
            [2] = {
                program_name = "advanced_npc:use_bed",
                arguments = {
                    pos = npc.locations.data.bed.primary,
                    action = npc.programs.const.node_ops.beds.LAY
                },
                interrupt_options = {
                    allow_rightclick = false
                }
            },
            [3] = {
                program_name = "advanced_npc:idle",
                arguments = {
                    acknowledge_nearby_objs = false,
                    wander_chance = 0
                },
                interrupt_options = {
                    allow_rightclick = false
                },
                is_state_program = true
            }
        }
    }
}

-- Program registrations
--npc.programs.register("schedules:default:sleep", function(self, args)
--    -- Walk to bed
--    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
--        new_program = "advanced_npc:walk_to_pos",
--        new_args = {
--            end_pos = {place_type=npc.locations.data.bed.primary, use_access_node=true},
--            walkable = {}
--        },
--        interrupt_options = {}
--    })
--    -- Use bed
--    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
--        new_program = "advanced_npc:use_bed",
--        new_args = {
--            pos = npc.locations.data.bed.primary,
--            action = npc.programs.const.node_ops.beds.LAY
--        },
--        interrupt_options = {
--            allow_rightclick = false
--        }
--    })
--end)

npc.programs.register("schedules:default:wake_up", function(self, args)
    -- Use bed
    npc.exec.proc.enqueue(self, "advanced_npc:interrupt", {
        new_program = "advanced_npc:use_bed",
        new_args = {
            pos = npc.locations.data.bed.primary,
            action = npc.programs.const.node_ops.beds.GET_UP
        },
        interrupt_options = {
            allow_rightclick = false
        }
    })
end)

-- Register default occupation
npc.occupations.register_occupation(npc.occupations.basic_name, basic_def)