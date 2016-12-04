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
				action = function(self, player_name)
					minetest.chat_send_player(player_name, "Oh, never? How come! You should."..
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
	}
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
				action = function(npc, player_name)
					minetest.chat_send_player(player_name, "Then you are not worth my time.")
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