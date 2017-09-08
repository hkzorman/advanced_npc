----------------------------------------------------
-- Basic priest occupation for Advanced NPC (WIP)
-- By Zorman2000
----------------------------------------------------
-- The basic priest occupation is given to NPCs that spawn on houses
-- surrounding churchs. While on the church, the priest provides
-- universal wisdom and advice, and also heals the player a limited number of times.
-- DISCLAIMER: The "teachings" in this file come from a compilation of 15 principles shared
-- among religions around the world. Zorman2000 and other contributors are not
-- necessarily aligned with the principles and morals in these teachings, nor affiliated
-- to religions that promote them.

local priest_def = {
    dialogues = {
        type = "given",
        data = {
            {
                text = "Blessings be upon you, my child!",
                tags = {"unisex"}
            },
            {
                text = "The temple will always open the doors to everyone.",
                tags = {"unisex"}
            },
            {
                text = "Following the teachings is the path to a good life.",
                tags = {"unisex"}
            },
            {
                text = "Thanks for coming to greet me, I hope you have a blessed day! ",
                tags = {"unisex"}
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
                                        .."my child.\nTo mortals like you and me, the power of the Creator is\n"
                                        .." limited. Only though learning the teachings we are able to understand more"
                                        .."...\nBe safe my child.")
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
                                [1] = "Do unto others what you would have them do unto you",
                                [2] = "Honor your Father and Mother. Knowing them is the key to knowing ourselves",
                                [3] = "Sincerity is the way to heaven,\nand to think how to be sincere is the way of the man",
                                [4] = "Generosity, charity and kindness will open an individual to an unbounded reservoir of riches",
                                [5] = "Even as the scent dwells within the flower, so God within thine own heart forever abides",
                                [6] = "Acts of faith, prayer and meditation provide us with the strength that allows love for our fellow man to become an abiding force. Love is unifying.",
                                [7] = "Peacemakers are blessed.\nPeace is the natural result of individuals and nations living in close kinship",
                                [8] = "You reap what you sow.\nEven if it is a mystery, we are all ruled by this inevitable law of nature",
                                [9] = "The blessings of life are deeper than what can be appreciated by the senses",
                                [10] = "Do no harm, as we are part of the whole, and shouldn't perceive others as foreign or separate from ownself",
                                [11] = "The most beautiful thing a man can do is to forgive wrong",
                                [12] = "Judge not, lest ye be judged. Mankind is nothing but a great family and we all spring from common source",
                                [13] = "Anger clouds the mind in the very moments that clarity and objectivity are needed most.",
                                [14] = "Nature, Being, The Absolute, Creator... whatever name man chooses, there is but one force in the universe. All people and things are of one essence",
                                [15] = "Study the words, no doubt, but look behind them to the thought they indicate;\nhaving fond it, throw the words away. Live the spirit of them",
                                [16] = "The wise store up choice food and olive oil, \nbut fools gulp theirs down.",
                                [17] = "An inheritance claimed too soon \nwill not be blessed at the end.",
                                [18] = "Young men give glory in their strength, \nbut old men are honored for their gray hair.",
                                [19] = "Humility is the fear of the Creator, or whatever name man chooses; \nits wages are riches and honor in life.",
                                [20] = "Listen, my child, and be wise, \nand set your heart on the right path.",
                                [21] = "Do not speak to fools, \nfor they will scorn your prudent words.",
                                [22] = "The schemes of folly are sin, \nand people detest a mocker.",
                                [23] = "An honest answer is like a kiss on the lips.",
                                [24] = "Do not envy the wicked, \ndo not desire their company; \nfor their hearts plot violence, \nand their lips talk about making trouble.",
                                [25] = "Do not fret because of evildoers, for the evildoer has no future hope.",
                                [26] = "It is to one's honor to avoid strife, \nbut every fool is quick to quarrel"
                            }
                            npc.chat(self.npc_name, player:get_player_name(), teachings[math.random(1, #teachings)]
                                    ..". \nThese are the teachings of our Creator.")
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
    properties = {
        initial_trader_status = npc.trade.NONE,
        enable_gift_items_hints = false
    },

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
}

-- Register occupation
npc.occupations.register_occupation("basic_priest", priest_def)
