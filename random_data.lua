-- Random data provider to create random NPCs by Zorman2000


npc.data = {}

npc.data.DIALOGUES = {
	female = {},
	male = {}
}

-- Female dialogue options defined by phase
-- Phase 1
npc.data.DIALOGUES.female["phase1"] = {
	{
		text = "Hello there!"
	},
	{
		text = "How are you doing?"
	},
	{
		text = "Hey, I haven't seen you before!"
	},
	{
		text = "Just another day..."
	},
	{
		text = "The weather is nice today"
	},
	{
		text = "Hello! Have you been to the sea?",
		responses = {
			{
				text = "No, never before",
				action_type = "function",
				action = function(player_name, item)
					minetest.chat_send_player(player_name, "Oh, never? How come! You should."..
						"\nHere, take this. It will guide you to the sea...")
				end
			},
			{
				text = "Yes, sure",
				action_type = "dialogue",
				action = {
					text = "It's so beautiful, and big, and large, and infinite, and..."
				}
			},
			{
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
	{
		text = "Hello!"
	},
	{
		text = "Welcome to our village, stranger."
	},
	{
		text = "Just a great day to go to the woods..."
	},
	{
		text = "Bah, stone! Useless stuff."
	},
	{
		text = "What do you think of this weather?"
	},
	{
		text = "Hello! Have you been to the sea?",
		responses = {
			{
				text = "No, never before",
				action_type = "function",
				action = function(player_name, item)
					minetest.chat_send_player(player_name, "Then you are not worth my time.")
				end
			},
			{
				text = "Yes, sure",
				action_type = "dialogue",
				action = {
					text = "Then you should appreciate it as a great pirate of the seven seas do!"
				}
			},
			{
				text = "Of course! And to all the seas in the world!",
				action_type = "dialogue",
				action = {
					text = "No my friend, I don't think so! I have been to all the seas!"
				}
			}
		}
	}
}