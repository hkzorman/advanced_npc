-- Random data provider to create random NPCs by Zorman2000


npc.data = {}

npc.data.DIALOGUES = {
	female = {},
	male = {}
}

-- Female dialogue options defined by phase
-- Phase 1
npc.data.DIALOGUES.female["phase1"] = {
	[1] = {
		text = "Hello there!"
	},
	[2] = {
		text = "How are you doing?"
	},
	[3] = {
		text = "Hey, I haven't seen you before!"
	},
	[4] = {
		text = "Just another day..."
	},
	[5] = {
		text = "The weather is nice today"
	},
	[6] = {
		text = "Hello! Have you been to the sea?",
		responses = {
			[1] = {
				text = "No, never before",
				action_type = "function",
				action = function(self, player)
					minetest.chat_send_player(player:get_player_name(), "Oh, never? How come! You should."..
						"\nHere, take this. It will guide you to the sea...")
				end
			},
			[2] = {
				text = "Yes, sure",
				action_type = "dialogue",
				action = {
					text = "It's so beautiful, and big, and large, and infinite, and..."
				}
			},
			[3] = {
				text = "Of course! And to all the seas in the world!",
				action_type = "dialogue",
				action = {
					text = "Awww you are no fun then! Go on then know-it-all!"
				}
			}
		}
	},
  [7] = {
    text = "Hello there, could you help me?",
    flag = {name="received_money_help", value=false},
    responses = {
      [1] = {
        text = "Yes, how can I help?",
        action_type = "dialogue",
        action = {
          text = "Could you please give me 3 "..npc.trade.prices.currency.tier3.name.."?",
          responses = {
            [1] = {
              text = "Yes, ok, here",
              action_type = "function",
              action = function(self, player)
                -- Take item 
                local args = {
                  player=player, 
                  pos=nil, 
                  inv_list="main", 
                  item_name=npc.trade.prices.currency.tier3.string, 
                  count=3
                }
                npc.actions.execute(self, npc.actions.cmd.TAKE_ITEM, {
                  player=player:get_player_name(), 
                  pos=nil, 
                  inv_list="main", 
                  item_name=npc.trade.prices.currency.tier3.string, 
                  count=3
                })
                -- Send message
                minetest.chat_send_player(player:get_player_name(), "Thank you, thank you so much!")
                -- Set flag
                npc.add_flag(self, "received_money_help", true)
                -- Add chat line
                table.insert(self.dialogues.normal, npc.data.DIALOGUES.female["phase1"][8])
              end
            },
            [2] = {
              text = "No, I'm sorry",
              action_type = "dialogue",
              action = {
                text = "Oh..."
              }
            }
          }
        }
      },
      [2] = {
        text = "No, I'm sorry, can't now",
        action_type = "function",
        action = function(self, player)
          minetest.chat_send_player(player:get_player_name(), "Oh, ok...")
        end
      }
    }
  },
  [8] = {
    text = "Thank you so much for your help, thank you!",
    flag = {name="received_money_help", value=true}
  }
}

-- Phase 2
npc.data.DIALOGUES.female["phase2"] = {
	[1] = {
		text = "Hey buddy!"
	},
	[2] = {
		text = "Hey buddy!"
	},
	[3] = {
		text = "Hey buddy!"
	},
	[4] = {
		text = "Hey buddy!"
	}
}

-- Phase 3
npc.data.DIALOGUES.female["phase3"] = {
	[1] = {
		text = "Hi there! Great to see you!"
	},
	[2] = {
		text = "Hi there! Great to see you!"
	},
	[3] = {
		text = "Hi there! Great to see you!"
	},
	[4] = {
		text = "Hi there! Great to see you!"
	}
}

-- Phase 4
npc.data.DIALOGUES.female["phase4"] = {
	[1] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[2] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[3] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[4] = {
		text = "I was honestly looking forward to talk to you!"
	}
}

-- Phase 5
npc.data.DIALOGUES.female["phase5"] = {
	[1] = {
		text = "You are the love of my life"
	},
	[2] = {
		text = "You are the love of my life"
	},
	[3] = {
		text = "You are the love of my life"
	},
	[4] = {
		text = "You are the love of my life"
	}
}

-- Phase 6
npc.data.DIALOGUES.female["phase6"] = {
	[1] = {
		text = "You are the best thing that has happened to me!"
	},
	[2] = {
		text = "You are the best thing that has happened to me!"
	},
	[3] = {
		text = "You are the best thing that has happened to me!"
	},
	[4] = {
		text = "You are the best thing that has happened to me!"
	},
}


-- Male dialogue options defined by phase
-- Phase 1
npc.data.DIALOGUES.male["phase1"] = {
	[1] = {
		text = "Hello!"
	},
	[2] = {
		text = "Welcome to our village, stranger."
	},
	[3] = {
		text = "Just a great day to go to the woods..."
	},
	[4] = {
		text = "Bah, stone! Useless stuff."
	},
	[5] = {
		text = "What do you think of this weather?"
	},
    [6] = {
		text = "Hello! Have you been to the sea?",
		responses = {
			[1] = {
				text = "No, never before",
				action_type = "function",
				action = function(npc, player)
					minetest.chat_send_player(player:get_player_name(), "Then you are not worth my time.")
				end
			},
			[2] = {
				text = "Yes, sure",
				action_type = "dialogue",
				action = {
					text = "Then you should appreciate it as a great pirate of the seven seas do!"
				}
			},
			[3] = {
				text = "Of course! And to all the seas in the world!",
				action_type = "dialogue",
				action = {
					text = "No my friend, I don't think so! I have been to all the seas!"
				}
			}
		}
	}
}

-- Phase 2
npc.data.DIALOGUES.male["phase2"] = {
	[1] = {
		text = "Hey buddy!"
	},
	[2] = {
		text = "Hey buddy!"
	},
	[3] = {
		text = "Hey buddy!"
	},
	[4] = {
		text = "Hey buddy!"
	}
}

-- Phase 3
npc.data.DIALOGUES.male["phase3"] = {
	[1] = {
		text = "Hi there! Great to see you!"
	},
	[2] = {
		text = "Hi there! Great to see you!"
	},
	[3] = {
		text = "Hi there! Great to see you!"
	},
	[4] = {
		text = "Hi there! Great to see you!"
	}
}

-- Phase 4
npc.data.DIALOGUES.male["phase4"] = {
	[1] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[2] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[3] = {
		text = "I was honestly looking forward to talk to you!"
	},
	[4] = {
		text = "I was honestly looking forward to talk to you!"
	}
}

-- Phase 5
npc.data.DIALOGUES.male["phase5"] = {
	[1] = {
		text = "You are the love of my life"
	},
	[2] = {
		text = "You are the love of my life"
	},
	[3] = {
		text = "You are the love of my life"
	},
	[4] = {
		text = "You are the love of my life"
	}
}

-- Phase 6
npc.data.DIALOGUES.male["phase6"] = {
	[1] = {
		text = "You are the best thing that has happened to me!"
	},
	[2] = {
		text = "You are the best thing that has happened to me!"
	},
	[3] = {
		text = "You are the best thing that has happened to me!"
	},
	[4] = {
		text = "You are the best thing that has happened to me!"
	},
}

-- Names
npc.data.FIRST_NAMES = {
	female = {
		"Kimy",
		"Lili",
		"Coraline",
		"Gloria",
		"Mary",
		"Mayra",
		"Arlene",
		"Tita",
		"Lola",
		"Olivia",
		"Katherine",
		"Cataline",
		"Pinky",
		"Kathleen",
		"Marilyn",
		"Sunshine",
		"April",
		"Rainy",
		"Lulu",
		"Sandra",
		"Marlene",
		"Lany",
		"Zoe",
		"Jolie",
		"Vicky",
		"Natalia",
		"Evelyn",
		"Elizabeth",
		"Giselle",
		"Jasmine",
		"Karla",
		"Leslie",
		"Karen",
		"Dana",
		"Merry",
		"Helena",
		"Rose",
		"Thalia",
		"Luna",
		"Valery",
		"Carol",
		"Paulette",
		"Rosie",
		"Leti",
		"Sophie",
		"Miranda",
		"Arianne",
		"Lizzy",
		"Amy",
		"Chloe",
		"Alisson"
	},
	male = {
		"Jote",
		"Luis",
		"Charles",
		"Joseph",
		"Gerald",
		"Kiko",
		"Michael",
		"Alexis",
		"Rafa"
	}
}

-- Items
-- Favorite items, disliked items lists
npc.FAVORITE_ITEMS = {
  female = {},
  male = {}
}

npc.FAVORITE_ITEMS.female["phase1"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"},
  {item = "farming:seed_cotton",        
   response = "Thank you, I will plant this really soon",
   hint = "I would like to have some cotton plants around"},
  {item = "farming:seed_wheat",
   response = "Thank you! These seeds will make a good wheat plant!",
   hint = "I've been thinking I should get wheat seeds"},
  {item = "flowers:rose",        
   response = "Thanks...",
   hint = "Red roses make a nice gift!"},
  {item = "flowers:geranium",
   response = "Oh, for me? Thank you!",
   hint = "Blue geraniums are so beautiful"},
  {item = "default:clay_lump",        
   response = "Thanks! Now, what can I do with this...",
   hint = "If I had some clay lump, I may do some pottery"},
  {item = "mobs:meat_raw",
   response = "This will be great for tonight! Thanks",
   hint = "A good dinner always have meat"},
  {item = "mobs:leather",        
   response = "Thank you! I needed this leather!",
   hint = "If only I could get some leather"},
  {item = "default:sapling",
   response = "Now I can plant that tree...",
   hint = "I really would like an apple tree close by."}
}
npc.FAVORITE_ITEMS.female["phase2"] = {
  {item = "farming:cotton",        
   response = "This is going to be very helpful, thank you!",
   hint = "If I just had some cotton lying around..."},
  {item = "wool:white",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Have you seen a white sheep? I need some wool."}
}
npc.FAVORITE_ITEMS.female["phase3"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.female["phase4"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.female["phase5"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.female["phase6"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
-- Male
npc.FAVORITE_ITEMS.male["phase1"] = {
   {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"},
  {item = "farming:seed_cotton",        
   response = "Thank you, I will plant this really soon",
   hint = "I would like to have some cotton plants around"},
  {item = "farming:seed_wheat",
   response = "Thank you! These seeds will make a good wheat plant!",
   hint = "I've been thinking I should get wheat seeds"},
  {item = "default:wood",        
   response = "Thanks, I needed this.",
   hint = "Some wood without having to cut a tree would be good."},
  {item = "default:tree",
   response = "Excellent to get that furnace going!",
   hint = "I need logs, do you have some?"},
  {item = "default:clay_lump",        
   response = "Thanks! Now, what can I do with this...",
   hint = "I wish I had some clay"},
  {item = "mobs:meat_raw",
   response = "This makes a great meal. Thank you",
   hint = "Meat is always great"},
  {item = "mobs:leather",        
   response = "Time to tan some leathers!",
   hint = "I have been needing leather these days"},
  {item = "default:sapling",
   response = "Thanks, I will plant this right now",
   hint = "I really would like an apple tree close by."}
}
npc.FAVORITE_ITEMS.male["phase2"] = {
  {item = "farming:cotton",        
   response = "This is going to be very helpful, thank you!",
   hint = "If I just had some cotton lying around..."},
  {item = "wool:white",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Have you seen a white sheep? I need some wool."}
}
npc.FAVORITE_ITEMS.male["phase3"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.male["phase4"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "SOme fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.male["phase5"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}
npc.FAVORITE_ITEMS.male["phase6"] = {
  {item = "default:apple",        
   response = "Hey, I really wanted an apple, thank you!",
   hint = "I could really do with an apple..."},
  {item = "farming:bread",
   response = "Thanks, you didn't have to, but thanks...",
   hint = "Some fresh bread would be good!"}
}

-- Disliked items
npc.DISLIKED_ITEMS = {
  female = {
    {item = "default:stone",        
     response = "Stone, oh... why do you give me this?",
     hint = "Why would someone want a stone?"},
    {item = "default:cobble",
     response = "Cobblestone? No, no, why?",
     hint = "Anything worst than stone is cobblestone."}
  },
  male = {
    {item = "default:stone",        
     response = "Bah! Stone? I don't need this thing!",
     hint = "Stones are useless!"},
    {item = "default:cobble",
     response = "Cobblestone!? Wow, you sure think a lot before giving a gift...",
     hint = "If I really hate something, that's cobblestone!"}
  }
}