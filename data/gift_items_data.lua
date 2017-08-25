------------------------------------------------------------------------------
-- Gift Items data definitions
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- PHASE 1
------------------------------------------------------------------------------

npc.relationships.register_favorite_item("default:apple", "phase1", "female", {
	responses = {"Hey, I really wanted an apple, thank you!"},
   	hints = {"I could really do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase1", "female", {
	responses = {"Thanks, you didn't have to, but thanks..."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("farming:seed_cotton", "phase1", "female", {      
   responses = {"Thank you, I will plant this really soon"},
   hints = {"I would like to have some cotton plants around"}
})

npc.relationships.register_favorite_item("farming:seed_wheat", "phase1", "female", {
   responses = {"Thank you! These seeds will make a good wheat plant!"},
   hints = {"I've been thinking I should get wheat seeds"}
})

npc.relationships.register_favorite_item("flowers:rose", "phase1", "female", {      
   responses = {"Thanks..."},
   hints = {"Red roses make a nice gift!"}
})

npc.relationships.register_favorite_item("flowers:geranium", "phase1", "female", {
   responses = {"Oh, for me? Thank you!"},
   hints = {"Blue geraniums are so beautiful"}
})

npc.relationships.register_favorite_item("default:clay_lump", "phase1", "female", {       
   responses = {"Thanks! Now, what can I do with this..."},
   hints = {"If I had some clay lump, I may do some pottery"}
})

npc.relationships.register_favorite_item("mobs:meat_raw", "phase1", "female", {
   responses = {"This will be great for tonight! Thanks"},
   hints = {"A good dinner always have meat"}
})

npc.relationships.register_favorite_item("mobs:leather", "phase1", "female", {      
   responses = {"Thank you! I needed this!"},
   hints = {"If only I could get some leather"}
})

npc.relationships.register_favorite_item("default:sapling", "phase1", "female", {
   responses = {"Now I can plant that tree..."},
   hints = {"I really would like an apple tree close by."}
})


npc.relationships.register_favorite_item("farming:cotton", "phase2", "female", {  
   responses = {"This is going to be very helpful, thank you!"},
   hints = {"If I just had some cotton lying around..."}
})

npc.relationships.register_favorite_item("wool:white", "phase2", "female", {
   responses = {"Thanks, you didn't have to, but thanks..."},
   hints = {"Have you seen a sheep? I wish I had some white wool..."}
})


npc.relationships.register_favorite_item("default:apple", "phase3", "female", {
	responses = {"Hey, I really wanted an apple, thank you!"},
   	hints = {"I could really do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase3", "female", {
	responses = {"Thanks, you didn't have to, but thanks..."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase4", "female", {
	responses = {"Hey, I really wanted an apple, thank you!"},
   	hints = {"I could really do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase4", "female", {
	responses = {"Thanks, you didn't have to, but thanks..."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase5", "female", {
	responses = {"Hey, I really wanted an apple, thank you!"},
   	hints = {"I could really do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase5", "female", {
	responses = {"Thanks, you didn't have to, but thanks..."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase6", "female", {
	responses = {"Hey, I really wanted an apple, thank you!"},
   	hints = {"I could really do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase6", "female", {
	responses = {"Thanks, you didn't have to, but thanks..."},
	hints = {"Some fresh bread would be good!"}
})


-- Male
npc.relationships.register_favorite_item("default:apple", "phase1", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase1", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("farming:seed_cotton", "phase1", "male", { 
   responses = {"Thank you, I will plant this soon"},
   hints = {"I would like to have some cotton plants around."}
})

npc.relationships.register_favorite_item("farming:seed_wheat", "phase1", "male", {
   responses = {"Thank you! These seeds will make a good wheat plant!"},
   hints = {"I've been thinking I should get wheat seeds."}
})

npc.relationships.register_favorite_item("default:wood", "phase1", "male", {       
   responses = {"Thanks, I needed this."},
   hints = {"Some wood without having to cut a tree would be good.}"}
})

npc.relationships.register_favorite_item("default:tree", "phase1", "male", {
   responses = {"Excellent to get that furnace going!"},
   hints = {"I'm looking for some logs"}
})

npc.relationships.register_favorite_item("default:clay_lump", "phase1", "male", {        
   responses = {"Thanks! Now, what can I do with this..."},
   hints = {"Now, some clay would be good."}
})

npc.relationships.register_favorite_item("mobs:meat_raw", "phase1", "male", {
   responses = {"This makes a great meal. Thank you"},
   hints = {"Meat is always great"},
})

npc.relationships.register_favorite_item("mobs:leather", "phase1", "male", {       
   responses = {"Time to tan some leathers!"},
   hints = {"I have been needing leather these days."}
})

npc.relationships.register_favorite_item("default:sapling", "phase1", "male", {
   responses = {"Thanks, I will plant this right now"},
   hints = {"I really would like an apple tree close by."}
})

npc.relationships.register_favorite_item("default:apple", "phase2", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase2", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase3", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase3", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase4", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase4", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase5", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase5", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

npc.relationships.register_favorite_item("default:apple", "phase6", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_favorite_item("farming:bread", "phase6", "male", {
	responses = {"Thank you! I was hungry."},
	hints = {"Some fresh bread would be good!"}
})

-- Disliked items
-- Female
npc.relationships.register_disliked_item("default:stone", "female", {
	responses = {"A stone, oh... why do you give this to me?"},
   	hints = {"Why would someone want a stone?"}
})

npc.relationships.register_disliked_item("default:cobble", "female", {
	responses = {"Cobblestone? No, no, why?"},
	hints = {"Anything worst than stone is cobblestone."}
})

-- Male
npc.relationships.register_disliked_item("default:stone", "male", {
	responses = {"Good apple, thank you!"},
   	hints = {"I could do with an apple..."}
})

npc.relationships.register_disliked_item("default:cobble", "male", {
	responses = {"Cobblestone!? Wow, you sure think a lot before giving a gift..."},
	hints = {"If I really hate something, that's cobblestone!"}
})

npc.log("INFO", "Registered gift items: "..dump(npc.relationships.gift_items))
npc.log("INFO", "Registered dialogues: "..dump(npc.dialogue.registered_dialogues))