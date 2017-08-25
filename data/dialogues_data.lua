


-- Phase 1 dialogues, unisex

npc.dialogue.register_dialogue({
	text = "Hello there!",
	tags = {"unisex", "phase1"}
})

npc.dialogue.register_dialogue({
	text = "How are you doing?",
	tags = {"unisex", "phase1"}
})

npc.dialogue.register_dialogue({
	text = "Just living another day...",
	tags = {"unisex", "phase1"}
})

-- Phase 1 dialogues, female

npc.dialogue.register_dialogue({
	text = "Is there any woman in this area more beautiful than I am?",
	tags = {"female", "phase1"}
})

npc.dialogue.register_dialogue({
	text = "Hello! Have you been to the sea?",
	tags = {"female", "phase1"},
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
})

npc.dialogue.register_dialogue({
    text = "Hello there, could you help me?",
    tags = {"phase1", "female"},
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
                			if npc.actions.execute(self, npc.actions.cmd.TAKE_ITEM, {
                  				player=player:get_player_name(), 
                  				pos=nil, 
                  				inv_list="main", 
                  				item_name=npc.trade.prices.currency.tier3.string, 
                  				count=3
                			}) then
                				-- Send message
                				npc.chat(self.npc_name, player:get_player_name(), "Thank you, thank you so much!")
                				-- Set flag
                				npc.add_flag(self, "received_money_help", true)
                				-- Add chat line
                				--table.insert(self.dialogues.normal, npc.data.DIALOGUES.female["phase1"][8])
                			else
                				npc.chat(self.npc_name, player:get_player_name(), "Looks like you don't have that amount of money...")
                			end
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
          		npc.chat(self.npc_name, player:get_player_name(), "Oh, ok...")
        	end
      	}
    }
})

npc.dialogue.register_dialogue({
    text = "Thank you so much for your help, thank you!",
    flag = {name="received_money_help", value=true},
    tags = {"phase1", "female"}
})

-- Phase 1 dialogues, male

npc.dialogue.register_dialogue({
	text = "Hunting is the best pasttime!",
	tags = {"male", "phase1"}
})

npc.dialogue.register_dialogue({
	text = "I hope my wheat grows well this harvest.",
	tags = {"male", "default_farmer"}
})